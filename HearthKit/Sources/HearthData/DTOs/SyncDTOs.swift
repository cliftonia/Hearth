import Foundation

// The shapes Hearth Hub exchanges, as written down in the hub's docs/WIRE_FORMAT.md. Times are `Date`s, read and
// written in the wire form by `WireTime.encoder()` and `WireTime.decoder()`.

/// What `GET /health` answers.
public struct SyncHealthDTO: Codable, Sendable, Equatable {
    public let ok: Bool
    public let seq: Int
    public let hubId: String
    public let authRequired: Bool?

    public init(ok: Bool, seq: Int, hubId: String, authRequired: Bool?) {
        self.ok = ok
        self.seq = seq
        self.hubId = hubId
        self.authRequired = authRequired
    }
}

/// One item as the hub holds it, in the list of changes and in the answer to a `PUT`.
public struct SyncEnvelopeDTO: Codable, Sendable, Equatable {
    public let kind: String
    public let id: String
    public let updatedAt: Date
    public let updatedBy: String
    public let deleted: Bool
    /// The item itself, kept as raw JSON until its kind is known; `{}` in a tombstone.
    public let body: JSONValue?
    public let seq: Int

    public init(kind: String, id: String, updatedAt: Date, updatedBy: String, deleted: Bool, body: JSONValue?, seq: Int) {
        self.kind = kind
        self.id = id
        self.updatedAt = updatedAt
        self.updatedBy = updatedBy
        self.deleted = deleted
        self.body = body
        self.seq = seq
    }
}

/// One page of `GET /v1/changes`.
public struct SyncChangesDTO: Codable, Sendable, Equatable {
    public let hubId: String
    public let items: [SyncEnvelopeDTO]
    /// The cursor to ask from next.
    public let next: Int
    public let hasMore: Bool

    public init(hubId: String, items: [SyncEnvelopeDTO], next: Int, hasMore: Bool) {
        self.hubId = hubId
        self.items = items
        self.next = next
        self.hasMore = hasMore
    }
}

/// The body of `PUT /v1/items/<kind>/<id>`.
public struct SyncPutDTO: Codable, Sendable, Equatable {
    public let updatedAt: Date
    public let updatedBy: String
    public let deleted: Bool
    public let body: JSONValue?

    public init(updatedAt: Date, updatedBy: String, deleted: Bool, body: JSONValue?) {
        self.updatedAt = updatedAt
        self.updatedBy = updatedBy
        self.deleted = deleted
        self.body = body
    }
}

/// What the hub answered to a `PUT`: kept, refused for a newer item it holds, or refused as too large.
public enum SyncPutResultDTO: Sendable, Equatable {
    case accepted(SyncEnvelopeDTO)
    /// The hub holds a newer version, which the device is to take instead.
    case conflict(SyncEnvelopeDTO)
    /// The item is larger than the hub takes, so it was not sent.
    case tooLarge
}

/// The answer to a `PUT`, accepted or not.
struct SyncPutAnswerDTO: Decodable {
    let accepted: Bool
    let item: SyncEnvelopeDTO
}

// MARK: - Bodies

/// A conversation's body, schema 1. Optional fields are optional here so that a body missing them still reads.
public struct ConversationBodyDTO: Codable, Sendable, Equatable {
    public enum CodingKeys: String, CodingKey, CaseIterable {
        case schema, title, modelId, isPinned, projectId, createdAt, lastActivityAt, messages
    }

    public let schema: Int
    public let title: String?
    public let modelId: String?
    public let isPinned: Bool?
    public let projectId: String?
    public let createdAt: Date
    public let lastActivityAt: Date?
    public let messages: [MessageDTO]?

    public init(
        schema: Int, title: String?, modelId: String?, isPinned: Bool?, projectId: String?,
        createdAt: Date, lastActivityAt: Date?, messages: [MessageDTO]?
    ) {
        self.schema = schema
        self.title = title
        self.modelId = modelId
        self.isPinned = isPinned
        self.projectId = projectId
        self.createdAt = createdAt
        self.lastActivityAt = lastActivityAt
        self.messages = messages
    }
}

/// One message of a conversation's body.
public struct MessageDTO: Codable, Sendable, Equatable {
    public enum CodingKeys: String, CodingKey, CaseIterable {
        case id, role, text, thinking, thinkingSeconds, sources, images, documents, otherVersions, versionIndex, isResearch, createdAt
    }

    public let id: String
    public let role: String
    public let text: String?
    public let thinking: String?
    public let thinkingSeconds: Int?
    public let sources: [SearchSourceDTO]?
    /// JPEG pictures, Base64 on the wire.
    public let images: [Data]?
    public let documents: [DocumentDTO]?
    public let otherVersions: [ReplyVersionDTO]?
    public let versionIndex: Int?
    public let isResearch: Bool?
    public let createdAt: Date

    public init(
        id: String, role: String, text: String?, thinking: String?, thinkingSeconds: Int?, sources: [SearchSourceDTO]?, images: [Data]?,
        documents: [DocumentDTO]?, otherVersions: [ReplyVersionDTO]?, versionIndex: Int?, isResearch: Bool?, createdAt: Date
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.thinking = thinking
        self.thinkingSeconds = thinkingSeconds
        self.sources = sources
        self.images = images
        self.documents = documents
        self.otherVersions = otherVersions
        self.versionIndex = versionIndex
        self.isResearch = isResearch
        self.createdAt = createdAt
    }
}

/// An earlier or later attempt at a reply.
public struct ReplyVersionDTO: Codable, Sendable, Equatable {
    public let text: String?
    public let thinking: String?
    public let thinkingSeconds: Int?
    public let sources: [SearchSourceDTO]?

    public init(text: String?, thinking: String?, thinkingSeconds: Int?, sources: [SearchSourceDTO]?) {
        self.text = text
        self.thinking = thinking
        self.thinkingSeconds = thinkingSeconds
        self.sources = sources
    }
}

/// A web page a reply was written from.
public struct SearchSourceDTO: Codable, Sendable, Equatable {
    public let title: String?
    public let url: String
    public let snippet: String?

    public init(title: String?, url: String, snippet: String?) {
        self.title = title
        self.url = url
        self.snippet = snippet
    }
}

/// A file reduced to its text, attached to a message or kept by a project.
public struct DocumentDTO: Codable, Sendable, Equatable {
    public enum CodingKeys: String, CodingKey, CaseIterable {
        case id, name, text
    }

    public let id: String
    public let name: String?
    public let text: String?

    public init(id: String, name: String?, text: String?) {
        self.id = id
        self.name = name
        self.text = text
    }
}

/// A project's body, schema 1.
public struct ProjectBodyDTO: Codable, Sendable, Equatable {
    public enum CodingKeys: String, CodingKey, CaseIterable {
        case schema, name, instructions, documents, createdAt
    }

    public let schema: Int
    public let name: String?
    public let instructions: String?
    public let documents: [DocumentDTO]?
    public let createdAt: Date

    public init(schema: Int, name: String?, instructions: String?, documents: [DocumentDTO]?, createdAt: Date) {
        self.schema = schema
        self.name = name
        self.instructions = instructions
        self.documents = documents
        self.createdAt = createdAt
    }
}

/// A memory's body, schema 1.
public struct MemoryBodyDTO: Codable, Sendable, Equatable {
    public enum CodingKeys: String, CodingKey, CaseIterable {
        case schema, text, isFromUser, createdAt
    }

    public let schema: Int
    public let text: String
    public let isFromUser: Bool?
    public let createdAt: Date

    public init(schema: Int, text: String, isFromUser: Bool?, createdAt: Date) {
        self.schema = schema
        self.text = text
        self.isFromUser = isFromUser
        self.createdAt = createdAt
    }
}
