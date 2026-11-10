import Foundation
import HearthData

public enum PromptRole: String, Sendable {
    case system
    case user
    case assistant
    /// The results of a web search the model asked for.
    case tool
}

public struct PromptMessage: Sendable, Equatable {
    public let role: PromptRole
    public let text: String
    public let imagesJPEG: [Data]
    /// On an assistant message: the web searches the model asked for in that turn.
    public let searchQueries: [String]

    public init(role: PromptRole, text: String, imagesJPEG: [Data] = [], searchQueries: [String] = []) {
        self.role = role
        self.text = text
        self.imagesJPEG = imagesJPEG
        self.searchQueries = searchQueries
    }
}

public struct ChatRequest: Sendable, Equatable {
    public let model: ChatModel
    public let messages: [PromptMessage]
    /// How hard a model that can think should; ignored for models that cannot.
    public let thinking: ThinkingLevelKind
    /// Whether the model may ask for a web search in this request.
    public let isWebSearchOffered: Bool

    public init(model: ChatModel, messages: [PromptMessage], thinking: ThinkingLevelKind = .medium, isWebSearchOffered: Bool = false) {
        self.model = model
        self.messages = messages
        self.thinking = thinking
        self.isWebSearchOffered = isWebSearchOffered
    }
}

public enum ChatDelta: Sendable, Equatable {
    case thinking(String)
    case text(String)
    /// The model asked for a web search.
    case searchRequested(SearchRequest)
}

public struct ChatDataProvider: Sendable {
    public let fetchModels: @Sendable (URL) async throws -> [ChatModel]
    public let streamChat: @Sendable (URL, ChatRequest) -> AsyncThrowingStream<ChatDelta, any Error>
    public let complete: @Sendable (URL, ChatRequest) async throws -> String

    public init(
        fetchModels: @escaping @Sendable (URL) async throws -> [ChatModel],
        streamChat: @escaping @Sendable (URL, ChatRequest) -> AsyncThrowingStream<ChatDelta, any Error>,
        complete: @escaping @Sendable (URL, ChatRequest) async throws -> String
    ) {
        self.fetchModels = fetchModels
        self.streamChat = streamChat
        self.complete = complete
    }
}

public extension ChatDataProvider {
    static func live(service: OllamaService = OllamaService()) -> ChatDataProvider {
        ChatDataProvider(
            fetchModels: { baseURL in
                try await service.fetchModels(baseURL: baseURL).compactMap(ChatModel.init(from:))
            },
            streamChat: { baseURL, request in
                let chunks = service.streamChat(baseURL: baseURL, request: OllamaChatRequestDTO(from: request, stream: true))
                return AsyncThrowingStream { continuation in
                    let task = Task {
                        do {
                            for try await chunk in chunks {
                                if let thinking = chunk.message?.thinking, !thinking.isEmpty {
                                    continuation.yield(.thinking(thinking))
                                }
                                if let text = chunk.message?.content, !text.isEmpty {
                                    continuation.yield(.text(text))
                                }
                                for call in chunk.message?.toolCalls ?? [] where call.function.name == OllamaToolDTO.webSearchName {
                                    if let query = call.function.arguments.query, !query.isEmpty {
                                        let isNews = call.function.arguments.category == OllamaToolDTO.newsCategory
                                        continuation.yield(.searchRequested(SearchRequest(query: query, kind: isNews ? .news : .general)))
                                    }
                                }
                            }
                            continuation.finish()
                        } catch {
                            continuation.finish(throwing: error)
                        }
                    }
                    continuation.onTermination = { _ in task.cancel() }
                }
            },
            complete: { baseURL, request in
                let chunk = try await service.chat(baseURL: baseURL, request: OllamaChatRequestDTO(from: request, stream: false))
                return chunk.message?.content ?? ""
            }
        )
    }
}

extension OllamaChatRequestDTO {
    init(from request: ChatRequest, stream: Bool) {
        self.init(
            model: request.model.id.rawValue,
            messages: request.messages.map(OllamaMessageDTO.init(from:)),
            stream: stream,
            think: request.model.canThink ? OllamaThinkDTO(from: request.thinking) : nil,
            tools: request.isWebSearchOffered && request.model.canUseTools ? [.webSearch] : nil
        )
    }
}

extension OllamaMessageDTO {
    init(from message: PromptMessage) {
        let calls = message.searchQueries.map { query in
            OllamaToolCallDTO(function: OllamaToolFunctionDTO(name: OllamaToolDTO.webSearchName, arguments: OllamaToolArgumentsDTO(query: query)))
        }
        self.init(
            role: message.role.rawValue,
            content: message.text,
            imagesBase64: message.imagesJPEG.isEmpty ? nil : message.imagesJPEG.map { $0.base64EncodedString() },
            toolCalls: calls.isEmpty ? nil : calls,
            toolName: message.role == .tool ? OllamaToolDTO.webSearchName : nil
        )
    }
}

extension OllamaThinkDTO {
    init(from level: ThinkingLevelKind) {
        switch level {
        case .off:
            self = .enabled(false)
        case .low, .medium, .high:
            self = .level(level.rawValue)
        }
    }
}
