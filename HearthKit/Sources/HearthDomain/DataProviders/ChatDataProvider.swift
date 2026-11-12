import Foundation
import HearthData

/// Who a message sent to the model is from.
public enum PromptRole: String, Sendable {
    case system
    case user
    case assistant
    /// The result of something the model asked for: a web search, or a change to what it remembers.
    case tool
}

/// One message as the model is sent it.
public struct PromptMessage: Sendable, Equatable {
    public let role: PromptRole
    public let text: String
    public let imagesJPEG: [Data]
    /// On an assistant message: the web searches the model asked for in that turn.
    public let searchQueries: [String]
    /// On an assistant message: the memory change the model asked for. On a tool message: the change this is the result of.
    public let memoryRequest: MemoryRequest?

    public init(role: PromptRole, text: String, imagesJPEG: [Data] = [], searchQueries: [String] = [], memoryRequest: MemoryRequest? = nil) {
        self.role = role
        self.text = text
        self.imagesJPEG = imagesJPEG
        self.searchQueries = searchQueries
        self.memoryRequest = memoryRequest
    }
}

/// Everything one call to the model needs: which model, what has been said and what it may ask for.
public struct ChatRequest: Sendable, Equatable {
    public let model: ChatModel
    public let messages: [PromptMessage]
    /// How hard a model that can think should; ignored for models that cannot.
    public let thinking: ThinkingLevelKind
    /// Whether the model may ask for a web search in this request.
    public let isWebSearchOffered: Bool
    /// Whether the model may change what it remembers about the user in this request.
    public let isMemoryOffered: Bool

    public init(
        model: ChatModel,
        messages: [PromptMessage],
        thinking: ThinkingLevelKind = .medium,
        isWebSearchOffered: Bool = false,
        isMemoryOffered: Bool = false
    ) {
        self.model = model
        self.messages = messages
        self.thinking = thinking
        self.isWebSearchOffered = isWebSearchOffered
        self.isMemoryOffered = isMemoryOffered
    }
}

/// One piece of a reply as it streams in.
public enum ChatDelta: Sendable, Equatable {
    case thinking(String)
    case text(String)
    /// The model asked for a web search.
    case searchRequested(SearchRequest)
    /// The model asked to change what it remembers.
    case memoryRequested(MemoryRequest)
}

/// How the domain reaches the chat server.
public struct ChatDataProvider: Sendable {
    /// The models on the given server that can hold a conversation.
    public let fetchModels: @Sendable (URL) async throws -> [ChatModel]
    /// The reply as it is written, piece by piece.
    public let streamChat: @Sendable (URL, ChatRequest) -> AsyncThrowingStream<ChatDelta, any Error>
    /// The whole text of a reply that is not streamed, for short side requests such as a title.
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

// MARK: - Live

public extension ChatDataProvider {
    /// Backed by an Ollama server.
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
                                for call in chunk.message?.toolCalls ?? [] {
                                    if let delta = ChatDelta(from: call) {
                                        continuation.yield(delta)
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

// MARK: - Mapping to and from the server's types

extension OllamaChatRequestDTO {
    /// Thinking and tools are sent only to models that have them.
    init(from request: ChatRequest, stream: Bool) {
        self.init(
            model: request.model.id.rawValue,
            messages: request.messages.map(OllamaMessageDTO.init(from:)),
            stream: stream,
            think: request.model.canThink ? OllamaThinkDTO(from: request.thinking) : nil,
            tools: Self.tools(for: request)
        )
    }

    /// The tools offered in this request; `nil` when there are none or the model cannot call tools.
    private static func tools(for request: ChatRequest) -> [OllamaToolDTO]? {
        guard request.model.canUseTools else {
            return nil
        }
        let tools = (request.isWebSearchOffered ? [OllamaToolDTO.webSearch] : []) + (request.isMemoryOffered ? OllamaToolDTO.memory : [])
        return tools.isEmpty ? nil : tools
    }
}

extension ChatDelta {
    /// The request a tool call stands for; `nil` for a call the app does not know or that lacks what it needs.
    init?(from call: OllamaToolCallDTO) {
        let arguments = call.function.arguments
        let text = arguments.text.flatMap { $0.isEmpty ? nil : $0 }
        let id = arguments.id.flatMap { $0.isEmpty ? nil : Memory.ID($0) }
        switch call.function.name {
        case OllamaToolDTO.webSearchName:
            guard let query = arguments.query, !query.isEmpty else {
                return nil
            }
            let isNews = arguments.category == OllamaToolDTO.newsCategory
            self = .searchRequested(SearchRequest(query: query, kind: isNews ? .news : .general))
        case OllamaToolDTO.saveMemoryName:
            guard let text else {
                return nil
            }
            self = .memoryRequested(.save(text))
        case OllamaToolDTO.updateMemoryName:
            guard let id, let text else {
                return nil
            }
            self = .memoryRequested(.update(id, text))
        case OllamaToolDTO.deleteMemoryName:
            guard let id else {
                return nil
            }
            self = .memoryRequested(.delete(id))
        default:
            return nil
        }
    }
}

extension OllamaToolCallDTO {
    /// The tool call that stands for a memory change, for showing the model what it asked for.
    init(from request: MemoryRequest) {
        switch request {
        case .save(let text):
            self.init(function: OllamaToolFunctionDTO(name: OllamaToolDTO.saveMemoryName, arguments: OllamaToolArgumentsDTO(text: text)))
        case .update(let id, let text):
            self.init(function: OllamaToolFunctionDTO(name: OllamaToolDTO.updateMemoryName, arguments: OllamaToolArgumentsDTO(text: text, id: id.rawValue)))
        case .delete(let id):
            self.init(function: OllamaToolFunctionDTO(name: OllamaToolDTO.deleteMemoryName, arguments: OllamaToolArgumentsDTO(id: id.rawValue)))
        }
    }
}

extension OllamaMessageDTO {
    /// An assistant message carries the tool calls made in it; a tool message names the tool it answers instead.
    init(from message: PromptMessage) {
        let isToolResult = message.role == .tool
        let searches = message.searchQueries.map { query in
            OllamaToolCallDTO(function: OllamaToolFunctionDTO(name: OllamaToolDTO.webSearchName, arguments: OllamaToolArgumentsDTO(query: query)))
        }
        let memoryCall = message.memoryRequest.map(OllamaToolCallDTO.init(from:))
        let calls = isToolResult ? [] : searches + (memoryCall.map { [$0] } ?? [])
        self.init(
            role: message.role.rawValue,
            content: message.text,
            imagesBase64: message.imagesJPEG.isEmpty ? nil : message.imagesJPEG.map { $0.base64EncodedString() },
            toolCalls: calls.isEmpty ? nil : calls,
            toolName: isToolResult ? (memoryCall?.function.name ?? OllamaToolDTO.webSearchName) : nil
        )
    }
}

extension OllamaThinkDTO {
    /// Off is sent as a plain `false`; every other level by its name.
    init(from level: ThinkingLevelKind) {
        switch level {
        case .off:
            self = .enabled(false)
        case .low, .medium, .high:
            self = .level(level.rawValue)
        }
    }
}
