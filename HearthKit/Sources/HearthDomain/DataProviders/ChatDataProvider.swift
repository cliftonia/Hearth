import Foundation
import HearthData

public enum PromptRole: String, Sendable {
    case system
    case user
    case assistant
}

public struct PromptMessage: Sendable, Equatable {
    public let role: PromptRole
    public let text: String
    public let imagesJPEG: [Data]

    public init(role: PromptRole, text: String, imagesJPEG: [Data] = []) {
        self.role = role
        self.text = text
        self.imagesJPEG = imagesJPEG
    }
}

public struct ChatRequest: Sendable, Equatable {
    public let model: ChatModel
    public let messages: [PromptMessage]
    /// Whether a model that can think should; ignored for models that cannot.
    public let isThinkingEnabled: Bool

    public init(model: ChatModel, messages: [PromptMessage], isThinkingEnabled: Bool = true) {
        self.model = model
        self.messages = messages
        self.isThinkingEnabled = isThinkingEnabled
    }
}

public enum ChatDelta: Sendable, Equatable {
    case thinking(String)
    case text(String)
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
            messages: request.messages.map { message in
                OllamaMessageDTO(
                    role: message.role.rawValue,
                    content: message.text,
                    imagesBase64: message.imagesJPEG.isEmpty ? nil : message.imagesJPEG.map { $0.base64EncodedString() }
                )
            },
            stream: stream,
            think: request.model.canThink ? request.isThinkingEnabled : nil
        )
    }
}
