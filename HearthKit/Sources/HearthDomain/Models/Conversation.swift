import Foundation
import HearthCore

/// Who wrote a message in a saved conversation.
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

/// A file attached to a message, reduced to the text read from it.
public struct AttachedDocument: Identifiable, Hashable, Codable, Sendable {
    public typealias ID = Tagged<AttachedDocument, UUID>

    public let id: ID
    public let name: String
    public let text: String

    public init(id: ID = ID(UUID()), name: String, text: String) {
        self.id = id
        self.name = name
        self.text = text
    }
}

/// One message of a conversation: what the user sent, or a reply to it.
public struct Message: Identifiable, Hashable, Codable, Sendable {
    public typealias ID = Tagged<Message, UUID>

    public let id: ID
    public let role: MessageRole
    public let text: String
    /// The model's reasoning before the reply; empty when it did none.
    public let thinking: String
    /// How long the reasoning took, where known.
    public let thinkingSeconds: Int?
    /// The web pages the reply was given to answer from.
    public let sources: [SearchSource]
    /// Photos attached to the message, as JPEG data.
    public let imagesJPEG: [Data]
    public let documents: [AttachedDocument]
    public let createdAt: Date

    public init(
        id: ID = ID(UUID()),
        role: MessageRole,
        text: String,
        thinking: String = "",
        thinkingSeconds: Int? = nil,
        sources: [SearchSource] = [],
        imagesJPEG: [Data] = [],
        documents: [AttachedDocument] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.thinking = thinking
        self.thinkingSeconds = thinkingSeconds
        self.sources = sources
        self.imagesJPEG = imagesJPEG
        self.documents = documents
        self.createdAt = createdAt
    }

    /// Messages saved before a field existed are read with that field's default.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(ID.self, forKey: .id),
            role: try container.decode(MessageRole.self, forKey: .role),
            text: try container.decode(String.self, forKey: .text),
            thinking: try container.decodeIfPresent(String.self, forKey: .thinking) ?? "",
            thinkingSeconds: try container.decodeIfPresent(Int.self, forKey: .thinkingSeconds),
            sources: try container.decodeIfPresent([SearchSource].self, forKey: .sources) ?? [],
            imagesJPEG: try container.decodeIfPresent([Data].self, forKey: .imagesJPEG) ?? [],
            documents: try container.decodeIfPresent([AttachedDocument].self, forKey: .documents) ?? [],
            createdAt: try container.decode(Date.self, forKey: .createdAt)
        )
    }

    /// Whether there is anything in the message to send or show.
    public var isEmpty: Bool {
        text.isEmpty && imagesJPEG.isEmpty && documents.isEmpty
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
            documents: documents,
            createdAt: createdAt
        )
    }
}

/// A chat with a model, as it is saved and listed.
public struct Conversation: Identifiable, Hashable, Codable, Sendable {
    public typealias ID = Tagged<Conversation, UUID>

    public let id: ID
    public let title: String
    /// The model the conversation is held with, if one has been set.
    public let modelID: ChatModel.ID?
    public let messages: [Message]
    public let isPinned: Bool
    /// A private conversation is given no memories and writes none.
    public let isPrivate: Bool
    public let createdAt: Date
    /// When the conversation was last active; the list is ordered by it.
    public let updatedAt: Date

    public init(
        id: ID = ID(UUID()),
        title: String = "",
        modelID: ChatModel.ID? = nil,
        messages: [Message] = [],
        isPinned: Bool = false,
        isPrivate: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.modelID = modelID
        self.messages = messages
        self.isPinned = isPinned
        self.isPrivate = isPrivate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Conversations saved before pinning or private chats existed carry neither mark; they are read as neither.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(ID.self, forKey: .id),
            title: try container.decode(String.self, forKey: .title),
            modelID: try container.decodeIfPresent(ChatModel.ID.self, forKey: .modelID),
            messages: try container.decode([Message].self, forKey: .messages),
            isPinned: try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false,
            isPrivate: try container.decodeIfPresent(Bool.self, forKey: .isPrivate) ?? false,
            createdAt: try container.decode(Date.self, forKey: .createdAt),
            updatedAt: try container.decode(Date.self, forKey: .updatedAt)
        )
    }

    /// A copy with the given parts replaced; anything left `nil` is kept.
    public func updating(
        title: String? = nil,
        modelID: ChatModel.ID? = nil,
        messages: [Message]? = nil,
        isPinned: Bool? = nil,
        isPrivate: Bool? = nil,
        updatedAt: Date? = nil
    ) -> Conversation {
        Conversation(
            id: id,
            title: title ?? self.title,
            modelID: modelID ?? self.modelID,
            messages: messages ?? self.messages,
            isPinned: isPinned ?? self.isPinned,
            isPrivate: isPrivate ?? self.isPrivate,
            createdAt: createdAt,
            updatedAt: updatedAt ?? self.updatedAt
        )
    }

    /// A copy whose message with the same identifier is swapped for the given one.
    public func replacing(_ message: Message) -> Conversation {
        updating(messages: messages.map { $0.id == message.id ? message : $0 })
    }
}
