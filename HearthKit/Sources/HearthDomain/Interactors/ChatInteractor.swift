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
        case thinking(String)
        case text(String)
    }

    public struct Turn: Sendable {
        public let history: [Message]
        public let model: ChatModel
        public let settings: ServerSettings
        public let searchMode: SearchModeKind
        public let style: ReplyStyle

        public init(history: [Message], model: ChatModel, settings: ServerSettings, searchMode: SearchModeKind, style: ReplyStyle) {
            self.history = history
            self.model = model
            self.settings = settings
            self.searchMode = searchMode
            self.style = style
        }
    }

    private static let maximumSources = 5
    /// How many times in one turn the model may go back to the web before it must answer.
    private static let maximumSearchRounds = 2

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
    /// Streams the reply. In automatic mode the model may stop to ask for a search; the results are
    /// handed back and it carries on, until it answers or has used its rounds.
    func stream(_ turn: Turn, report: (Event) -> Void) async throws {
        guard let baseURL = turn.settings.ollamaURL else {
            throw ChatError.serverNotConfigured
        }
        let searchURL = turn.settings.searchURL
        let isAutomatic = turn.searchMode == .automatic && searchURL != nil && turn.model.canUseTools
        let builder = PromptBuilder(instructions: turn.settings.customInstructions)
        var sources: [SearchSource] = []
        if turn.searchMode == .always, let searchURL, let query = builder.searchQuery(history: turn.history) {
            sources = await found(for: query, at: searchURL, excluding: [], report: report)
            report(.sources(sources))
        }
        var messages = builder.messages(history: turn.history, sources: sources, style: turn.style, now: now(), offersSearch: isAutomatic)
        var round = 0
        while true {
            let offersSearch = isAutomatic && round < Self.maximumSearchRounds
            let request = ChatRequest(
                model: turn.model,
                messages: messages,
                thinking: turn.style == .chat ? turn.settings.thinkingLevel : .off,
                isWebSearchOffered: offersSearch
            )
            let queries = try await reply(to: request, at: baseURL, report: report)
            guard offersSearch, let searchURL, !queries.isEmpty else {
                return
            }
            round += 1
            var fresh: [SearchSource] = []
            for query in queries {
                fresh += await found(for: query, at: searchURL, excluding: sources + fresh, report: report)
            }
            messages.append(PromptMessage(role: .assistant, text: "", searchQueries: queries))
            messages.append(PromptMessage(role: .tool, text: builder.searchResultsText(fresh, numberedFrom: sources.count + 1)))
            sources += fresh
            report(.sources(sources))
        }
    }

    /// Streams one reply from the model and returns the searches it asked for, if any.
    func reply(to request: ChatRequest, at baseURL: URL, report: (Event) -> Void) async throws -> [String] {
        var queries: [String] = []
        for try await delta in chat.streamChat(baseURL, request) {
            switch delta {
            case .thinking(let text):
                report(.thinking(text))
            case .text(let text):
                report(.text(text))
            case .searchRequested(let query):
                queries.append(query)
            }
        }
        return queries
    }

    /// Searches the web. A failed search is reported and the turn carries on without it: the reply matters more.
    func found(for query: String, at searchURL: URL, excluding known: [SearchSource], report: (Event) -> Void) async -> [SearchSource] {
        report(.searching(query))
        do {
            let results = try await search.search(searchURL, query).filter { result in
                !known.contains { $0.url == result.url }
            }
            return Array(results.prefix(Self.maximumSources))
        } catch {
            report(.searchFailed)
            return []
        }
    }
}
