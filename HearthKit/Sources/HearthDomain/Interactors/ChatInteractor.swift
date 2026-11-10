import Foundation

public enum ChatError: Error, Sendable, Equatable {
    case serverNotConfigured
    case noModelSelected
    case unreachable
    case server(message: String)
}

/// Runs one turn of a conversation: an optional web search, then the model's streamed reply.
public final class ChatInteractor: Sendable {
    public enum Event: Sendable, Equatable {
        case sources([SearchSource])
        case searchFailed
        case thinking(String)
        case text(String)
    }

    public struct Turn: Sendable {
        public let history: [Message]
        public let model: ChatModel
        public let settings: ServerSettings
        public let isSearchEnabled: Bool
        public let style: ReplyStyle

        public init(history: [Message], model: ChatModel, settings: ServerSettings, isSearchEnabled: Bool, style: ReplyStyle) {
            self.history = history
            self.model = model
            self.settings = settings
            self.isSearchEnabled = isSearchEnabled
            self.style = style
        }
    }

    private static let maximumSources = 5

    private let chat: ChatDataProvider
    private let search: SearchDataProvider
    private let now: @Sendable () -> Date
    private let promptBuilder = PromptBuilder()

    public init(chat: ChatDataProvider, search: SearchDataProvider, now: @escaping @Sendable () -> Date = { Date() }) {
        self.chat = chat
        self.search = search
        self.now = now
    }

    public func run(_ turn: Turn) -> AsyncThrowingStream<Event, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard let baseURL = turn.settings.ollamaURL else {
                        throw ChatError.serverNotConfigured
                    }
                    let sources = await self.sources(for: turn) { continuation.yield($0) }
                    let request = ChatRequest(
                        model: turn.model,
                        messages: self.promptBuilder.messages(history: turn.history, sources: sources, style: turn.style, now: self.now()),
                        isThinkingEnabled: turn.style == .chat
                    )
                    for try await delta in self.chat.streamChat(baseURL, request) {
                        switch delta {
                        case .thinking(let text):
                            continuation.yield(.thinking(text))
                        case .text(let text):
                            continuation.yield(.text(text))
                        }
                    }
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
        let request = ChatRequest(model: model, messages: [PromptMessage(role: .user, text: prompt)], isThinkingEnabled: false)
        let title = try await chat.complete(baseURL, request)
            .split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        return String(title.trimmingCharacters(in: CharacterSet(charactersIn: "\"'*#. ")).prefix(60))
    }

    /// A failed search is reported and the turn carries on without sources: the reply matters more.
    private func sources(for turn: Turn, report: (Event) -> Void) async -> [SearchSource] {
        guard turn.isSearchEnabled,
              let searchURL = turn.settings.searchURL,
              let query = promptBuilder.searchQuery(history: turn.history) else {
            return []
        }
        do {
            let sources = Array(try await search.search(searchURL, query).prefix(Self.maximumSources))
            report(.sources(sources))
            return sources
        } catch {
            report(.searchFailed)
            return []
        }
    }
}
