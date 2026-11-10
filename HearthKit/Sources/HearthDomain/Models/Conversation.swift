import Foundation
import HearthCore

public enum MessageRole: String, Codable, Sendable {
    case user
    case assistant
}

/// A web page the assistant was given to answer from.
public struct SearchSource: Identifiable, Hashable, Codable, Sendable {
    public let title: String
    public let url: URL
    public let snippet: String

    public var id: URL { url }

    /// Whether a link leads to a web page. Links from a model or a search engine are untrusted,
    /// and any other scheme could place a call or open another app when tapped.
    public static func isWebLink(_ url: URL) -> Bool {
        ["http", "https"].contains(url.scheme?.lowercased() ?? "") && url.host() != nil
    }

    public init(title: String, url: URL, snippet: String) {
        self.title = title
        self.url = url
        self.snippet = snippet
    }
}

public struct Message: Identifiable, Hashable, Codable, Sendable {
    public typealias ID = Tagged<Message, UUID>

    public let id: ID
    public let role: MessageRole
    public let text: String
    public let thinking: String
    public let thinkingSeconds: Int?
    public let sources: [SearchSource]
    public let imagesJPEG: [Data]
    public let createdAt: Date

    public init(
        id: ID = ID(UUID()),
        role: MessageRole,
        text: String,
        thinking: String = "",
        thinkingSeconds: Int? = nil,
        sources: [SearchSource] = [],
        imagesJPEG: [Data] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.thinking = thinking
        self.thinkingSeconds = thinkingSeconds
        self.sources = sources
        self.imagesJPEG = imagesJPEG
        self.createdAt = createdAt
    }

    /// A copy with the parts that grow while a reply streams in replaced.
    public func updating(text: String? = nil, thinking: String? = nil, thinkingSeconds: Int? = nil, sources: [SearchSource]? = nil) -> Message {
        Message(
            id: id,
            role: role,
            text: text ?? self.text,
            thinking: thinking ?? self.thinking,
            thinkingSeconds: thinkingSeconds ?? self.thinkingSeconds,
            sources: sources ?? self.sources,
            imagesJPEG: imagesJPEG,
            createdAt: createdAt
        )
    }
}

public struct Conversation: Identifiable, Hashable, Codable, Sendable {
    public typealias ID = Tagged<Conversation, UUID>

    public let id: ID
    public let title: String
    public let modelID: ChatModel.ID?
    public let messages: [Message]
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        id: ID = ID(UUID()),
        title: String = "",
        modelID: ChatModel.ID? = nil,
        messages: [Message] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.modelID = modelID
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public func updating(title: String? = nil, modelID: ChatModel.ID? = nil, messages: [Message]? = nil, updatedAt: Date? = nil) -> Conversation {
        Conversation(
            id: id,
            title: title ?? self.title,
            modelID: modelID ?? self.modelID,
            messages: messages ?? self.messages,
            createdAt: createdAt,
            updatedAt: updatedAt ?? self.updatedAt
        )
    }

    /// A copy whose message with the same identifier is swapped for the given one.
    public func replacing(_ message: Message) -> Conversation {
        updating(messages: messages.map { $0.id == message.id ? message : $0 })
    }
}
