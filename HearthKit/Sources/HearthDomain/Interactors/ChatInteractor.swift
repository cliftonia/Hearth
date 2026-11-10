import Foundation

public enum ChatError: Error, Sendable, Equatable {
    case serverNotConfigured
    case noModelSelected
    case unreachable
    case server(message: String)
}

/// When the web is searched during a turn.
public enum SearchModeKind: Sendable, Equatable {
    /// Never.
    case off
    /// Once, before the model replies, for the user's latest message.
    case always
    /// Whenever the model asks, for whatever it asks. Needs a model that can call tools.
    case automatic
}

/// Runs one turn of a conversation: the model's streamed reply, with any web searches along the way.
public final class ChatInteractor: Sendable {
    public enum Event: Sendable, Equatable {
        /// A web search has begun for this query.
        case searching(String)
        /// Every source found so far in this turn.
        case sources([SearchSource])
        case searchFailed
        /// What became of a change the model asked to make to its memory.
        case memory(MemoryOutcome)
        case thinking(String)
        case text(String)
    }

    public struct Turn: Sendable {
        public let history: [Message]
        public let model: ChatModel
        public let settings: ServerSettings
        public let searchMode: SearchModeKind
        public let style: ReplyStyle
        /// What is remembered about the user, to be carried into this turn.
        public let memories: [Memory]
        /// Makes a change to what is remembered. `nil` when the model may not change it.
        public let remember: (@Sendable (MemoryRequest) async -> MemoryOutcome)?

        public init(
            history: [Message],
            model: ChatModel,
            settings: ServerSettings,
            searchMode: SearchModeKind,
            style: ReplyStyle,
            memories: [Memory] = [],
            remember: (@Sendable (MemoryRequest) async -> MemoryOutcome)? = nil
        ) {
            self.history = history
            self.model = model
            self.settings = settings
            self.searchMode = searchMode
            self.style = style
            self.memories = memories
            self.remember = remember
        }
    }

    private static let maximumSources = 5
    /// How many times in one turn the model may go back to the web before it must answer.
    private static let maximumSearchRounds = 3
    /// How many of a search's results have their pages read, and how much of each page is kept.
    private static let maximumPagesRead = 3
    private static let pageExcerptLength = 2500
    /// How many changes to its memory the model may make in one turn.
    private static let maximumMemoryWrites = 2
    /// How many times the model is called in one turn, whatever it keeps asking for.
    private static let maximumRequests = 7

    private let chat: ChatDataProvider
    private let search: SearchDataProvider
    private let now: @Sendable () -> Date

    public init(chat: ChatDataProvider, search: SearchDataProvider, now: @escaping @Sendable () -> Date = { Date() }) {
        self.chat = chat
        self.search = search
        self.now = now
    }

    public func run(_ turn: Turn) -> AsyncThrowingStream<Event, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await self.stream(turn) { continuation.yield($0) }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: ChatError.remapping(error))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// A few words naming the conversation, written by the model.
    public func title(for userText: String, model: ChatModel, settings: ServerSettings) async throws -> String {
        guard let baseURL = settings.ollamaURL else {
            throw ChatError.serverNotConfigured
        }
        let prompt = "Write a title of at most five words for a conversation that begins with the message below. "
            + "Reply with the title only, without quotes or a full stop.\n\n\(userText.prefix(600))"
        let request = ChatRequest(model: model, messages: [PromptMessage(role: .user, text: prompt)], thinking: .off)
        let title = try await chat.complete(baseURL, request)
            .split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        return String(title.trimmingCharacters(in: CharacterSet(charactersIn: "\"'*#. ")).prefix(60))
    }

    /// Questions the user might ask next, written by the model. Empty when there is nothing to go on.
    public func followUps(history: [Message], model: ChatModel, settings: ServerSettings) async throws -> [String] {
        let transformer = FollowUpTransformer()
        guard let baseURL = settings.ollamaURL, let prompt = transformer.prompt(history: history) else {
            return []
        }
        let request = ChatRequest(model: model, messages: [PromptMessage(role: .user, text: prompt)], thinking: .off)
        return transformer.questions(from: try await chat.complete(baseURL, request))
    }
}

private extension ChatInteractor {
    /// Where and how a turn searches the web.
    struct SearchSetup {
        let url: URL
        let isReadingPages: Bool
        let builder: PromptBuilder
    }

    /// How far a turn has got: what has been said to the model, what has been found, and what allowance is used.
    struct Progress {
        var messages: [PromptMessage]
        var sources: [SearchSource]
        var searchRounds = 0
        var memoryWrites = 0
    }

    /// Streams the reply. Along the way the model may stop to ask for a web search or to change what it
    /// remembers; each request is carried out, its result handed back, and the model carries on until it
    /// answers or has used its allowance.
    func stream(_ turn: Turn, report: (Event) -> Void) async throws {
        guard let baseURL = turn.settings.ollamaURL else {
            throw ChatError.serverNotConfigured
        }
        let searchURL = turn.settings.searchURL
        let isAutomatic = turn.searchMode == .automatic && searchURL != nil && turn.model.canUseTools
        // Memory is written only from what the user says. A file or a web search anywhere in the conversation
        // stays in front of the model for the rest of it, so such a conversation writes no memories at all.
        let carriesOutsideText = turn.history.contains { !$0.documents.isEmpty || !$0.sources.isEmpty }
        let canRemember = turn.remember != nil && turn.model.canUseTools && !carriesOutsideText
        let builder = PromptBuilder(instructions: turn.settings.customInstructions, memories: turn.memories)
        var sources: [SearchSource] = []
        if turn.searchMode == .always, let searchURL, let query = builder.searchQuery(history: turn.history) {
            sources = await found(for: SearchRequest(query: query), at: searchURL, excluding: [], report: report)
            report(.sources(sources))
        }
        let messages = builder.messages(
            history: turn.history,
            sources: sources,
            style: turn.style,
            now: now(),
            offersSearch: isAutomatic,
            offersMemory: canRemember && sources.isEmpty
        )
        var progress = Progress(messages: messages, sources: sources)
        for _ in 0..<Self.maximumRequests {
            let offersSearch = isAutomatic && progress.searchRounds < Self.maximumSearchRounds
            // Once anything from the web is in the turn, memory is closed: a web page must not be able to plant a memory.
            let offersMemory = canRemember && progress.sources.isEmpty && progress.memoryWrites < Self.maximumMemoryWrites
            let request = ChatRequest(
                model: turn.model,
                messages: progress.messages,
                thinking: turn.style == .chat ? turn.settings.thinkingLevel : .off,
                isWebSearchOffered: offersSearch,
                isMemoryOffered: offersMemory
            )
            let asked = try await reply(to: request, at: baseURL, report: report)
            var hasActed = false
            if offersMemory, let remember = turn.remember, !asked.memoryChanges.isEmpty {
                await apply(asked.memoryChanges, using: remember, to: &progress, report: report)
                hasActed = true
            }
            if offersSearch, let searchURL, !asked.searches.isEmpty {
                let setup = SearchSetup(url: searchURL, isReadingPages: turn.settings.isPageReadingEnabled, builder: builder)
                await run(asked.searches, with: setup, progress: &progress, report: report)
                hasActed = true
            }
            guard hasActed else {
                return
            }
        }
    }

    /// Makes the memory changes the model asked for, within the turn's allowance, and tells it what became of each.
    func apply(
        _ changes: [MemoryRequest],
        using remember: @Sendable (MemoryRequest) async -> MemoryOutcome,
        to progress: inout Progress,
        report: (Event) -> Void
    ) async {
        for change in changes.prefix(Self.maximumMemoryWrites - progress.memoryWrites) {
            let outcome = await remember(change)
            progress.memoryWrites += 1
            report(.memory(outcome))
            progress.messages.append(PromptMessage(role: .assistant, text: "", memoryRequest: change))
            progress.messages.append(PromptMessage(role: .tool, text: Self.resultText(for: outcome), memoryRequest: change))
        }
    }

    /// Runs the searches the model asked for and hands it the results, with the text of the leading pages.
    func run(_ searches: [SearchRequest], with setup: SearchSetup, progress: inout Progress, report: (Event) -> Void) async {
        progress.searchRounds += 1
        var fresh: [SearchSource] = []
        for search in searches {
            fresh += await found(for: search, at: setup.url, excluding: progress.sources + fresh, report: report)
        }
        let results = setup.builder.searchResultsText(
            fresh,
            numberedFrom: progress.sources.count + 1,
            pages: setup.isReadingPages ? await pageTexts(for: fresh) : [:],
            isLastSearch: progress.searchRounds >= Self.maximumSearchRounds
        )
        progress.messages.append(PromptMessage(role: .assistant, text: "", searchQueries: searches.map(\.query)))
        progress.messages.append(PromptMessage(role: .tool, text: results))
        progress.sources += fresh
        report(.sources(progress.sources))
    }

    /// What the model is told became of its request, so that it can carry on.
    static func resultText(for outcome: MemoryOutcome) -> String {
        switch outcome {
        case .saved(let memory):
            "Saved as \(memory.id.rawValue). Carry on with your reply."
        case .updated(let memory):
            "Updated \(memory.id.rawValue). Carry on with your reply."
        case .deleted(let memory):
            "Forgot \(memory.id.rawValue). Carry on with your reply."
        case .refused(.empty):
            "Nothing was saved: the memory was empty."
        case .refused(.alreadySaved):
            "That is already remembered. Carry on with your reply."
        case .refused(.full):
            "Memory is full. Update or delete an entry instead, or carry on."
        case .refused(.notFound):
            "There is no memory with that id. Carry on with your reply."
        case .refused(.writtenByUser):
            "The user wrote that memory themselves, so only they can change it, in Settings. Tell them so, then carry on."
        case .refused(.notStored):
            "The memory could not be stored just now. Carry on with your reply."
        }
    }

    /// Streams one reply from the model and returns what it asked for along the way.
    func reply(to request: ChatRequest, at baseURL: URL, report: (Event) -> Void) async throws -> (searches: [SearchRequest], memoryChanges: [MemoryRequest]) {
        var searches: [SearchRequest] = []
        var memoryChanges: [MemoryRequest] = []
        for try await delta in chat.streamChat(baseURL, request) {
            switch delta {
            case .thinking(let text):
                report(.thinking(text))
            case .text(let text):
                report(.text(text))
            case .searchRequested(let search):
                searches.append(search)
            case .memoryRequested(let change):
                memoryChanges.append(change)
            }
        }
        return (searches, memoryChanges)
    }

    /// Searches the web. A failed search is reported and the turn carries on without it: the reply matters more.
    func found(for request: SearchRequest, at searchURL: URL, excluding known: [SearchSource], report: (Event) -> Void) async -> [SearchSource] {
        report(.searching(request.query))
        do {
            let results = try await search.search(searchURL, request).filter { result in
                !known.contains { $0.url == result.url }
            }
            return Array(results.prefix(Self.maximumSources))
        } catch {
            report(.searchFailed)
            return []
        }
    }

    /// Reads the pages behind the leading results, all at once. A page that cannot be read is simply
    /// left out: the result's snippet still stands, and the reply matters more than any one page.
    func pageTexts(for sources: [SearchSource]) async -> [URL: String] {
        let fetchPage = search.fetchPage
        let excerptLength = Self.pageExcerptLength
        return await withTaskGroup(of: (URL, String?).self) { group in
            for source in sources.prefix(Self.maximumPagesRead) {
                group.addTask {
                    guard let html = try? await fetchPage(source.url) else {
                        return (source.url, nil)
                    }
                    let text = HTMLTextTransformer().text(from: html, maximumLength: excerptLength)
                    return (source.url, text.count > 200 ? text : nil)
                }
            }
            var pages: [URL: String] = [:]
            for await (url, text) in group {
                pages[url] = text
            }
            return pages
        }
    }
}
