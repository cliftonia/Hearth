import Foundation
import HearthCore
import HearthData

/// Why a received item could not be read into the app's models.
public enum SyncMappingError: Error, Sendable, Equatable {
    /// An identifier that should be a UUID is not one.
    case invalidIdentifier
    /// A message's role is not one this app knows.
    case unknownRole
}

// MARK: - From the wire

public extension Conversation {
    /// A conversation from its synced body. A synced conversation is never private.
    ///
    /// - Parameters:
    ///   - id: The item's identifier, from its envelope.
    ///   - modifiedAt: The envelope's `updatedAt`.
    init(from dto: ConversationBodyDTO, id: Conversation.ID, modifiedAt: Date) throws {
        self.init(
            id: id,
            title: dto.title ?? "",
            modelID: dto.modelId.map { ChatModel.ID($0) },
            messages: try (dto.messages ?? []).map(Message.init(from:)),
            isPinned: dto.isPinned ?? false,
            isPrivate: false,
            projectID: dto.projectId.flatMap { UUID(uuidString: $0) }.map { Project.ID($0) },
            createdAt: dto.createdAt,
            updatedAt: dto.lastActivityAt ?? dto.createdAt,
            modifiedAt: modifiedAt
        )
    }
}

public extension Message {
    /// A message from its synced form. Fails on an identifier that is not a UUID or a role this app does not know.
    init(from dto: MessageDTO) throws {
        guard let uuid = UUID(uuidString: dto.id) else {
            throw SyncMappingError.invalidIdentifier
        }
        guard let role = MessageRole(rawValue: dto.role) else {
            throw SyncMappingError.unknownRole
        }
        self.init(
            id: ID(uuid),
            role: role,
            text: dto.text ?? "",
            thinking: dto.thinking ?? "",
            thinkingSeconds: dto.thinkingSeconds,
            sources: (dto.sources ?? []).compactMap(SearchSource.init(from:)),
            imagesJPEG: dto.images ?? [],
            documents: (dto.documents ?? []).map(AttachedDocument.init(from:)),
            otherVersions: (dto.otherVersions ?? []).map(ReplyVersion.init(from:)),
            versionIndex: dto.versionIndex ?? 0,
            isResearch: dto.isResearch ?? false,
            createdAt: dto.createdAt
        )
    }
}

public extension ReplyVersion {
    init(from dto: ReplyVersionDTO) {
        self.init(
            text: dto.text ?? "",
            thinking: dto.thinking ?? "",
            thinkingSeconds: dto.thinkingSeconds,
            sources: (dto.sources ?? []).compactMap(SearchSource.init(from:))
        )
    }
}

public extension SearchSource {
    /// A source from its synced form; `nil` when its address cannot be read as one, which no app writes.
    init?(from dto: SearchSourceDTO) {
        // A source from another device is only ever a web page: anything else could open an app or a file when tapped.
        guard let url = URL(string: dto.url, encodingInvalidCharacters: false), SearchSource.isWebLink(url) else {
            return nil
        }
        self.init(title: dto.title ?? "", url: url, snippet: dto.snippet ?? "")
    }
}

public extension AttachedDocument {
    /// A document from its synced form. One whose identifier is not a UUID is given a new one.
    init(from dto: DocumentDTO) {
        self.init(id: ID(UUID(uuidString: dto.id) ?? UUID()), name: dto.name ?? "", text: dto.text ?? "")
    }
}

// MARK: - To the wire

public extension ConversationBodyDTO {
    init(from conversation: Conversation) {
        self.init(
            schema: SyncWire.schema,
            title: conversation.title,
            modelId: conversation.modelID?.rawValue,
            isPinned: conversation.isPinned,
            projectId: conversation.projectID?.rawValue.uuidString.lowercased(),
            createdAt: conversation.createdAt,
            lastActivityAt: conversation.updatedAt,
            messages: conversation.messages.map(MessageDTO.init(from:))
        )
    }
}

public extension MessageDTO {
    init(from message: Message) {
        self.init(
            id: message.id.rawValue.uuidString.lowercased(),
            role: message.role.rawValue,
            text: message.text,
            thinking: message.thinking,
            thinkingSeconds: message.thinkingSeconds,
            sources: message.sources.map(SearchSourceDTO.init(from:)),
            images: message.imagesJPEG,
            documents: message.documents.map(DocumentDTO.init(from:)),
            otherVersions: message.otherVersions.map(ReplyVersionDTO.init(from:)),
            versionIndex: message.versionIndex,
            isResearch: message.isResearch,
            createdAt: message.createdAt
        )
    }
}

public extension ReplyVersionDTO {
    init(from version: ReplyVersion) {
        self.init(
            text: version.text,
            thinking: version.thinking,
            thinkingSeconds: version.thinkingSeconds,
            sources: version.sources.map(SearchSourceDTO.init(from:))
        )
    }
}

public extension SearchSourceDTO {
    init(from source: SearchSource) {
        self.init(title: source.title, url: source.url.absoluteString, snippet: source.snippet)
    }
}

public extension DocumentDTO {
    init(from document: AttachedDocument) {
        self.init(id: document.id.rawValue.uuidString.lowercased(), name: document.name, text: document.text)
    }
}
