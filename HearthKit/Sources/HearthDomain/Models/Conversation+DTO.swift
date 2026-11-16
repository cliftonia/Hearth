import Foundation
import HearthCore
import HearthData

/// Why a received item could not be read into the app's models.
public enum SyncMappingError: Error, Sendable, Equatable {
    /// An identifier that should be a UUID is not one.
    case invalidIdentifier
    /// A message's role is not one this app knows.
    case unknownRole
    /// A task's schedule is of a kind this app does not know, or is missing what its kind needs.
    case invalidSchedule
    /// A task names no model to run with.
    case missingModel
}

// MARK: - From the wire

public extension Conversation {
    /// A conversation from its synced body. A synced conversation is never private.
    ///
    /// - Parameters:
    ///   - id: The item's identifier, from its envelope.
    ///   - modifiedAt: The envelope's `updatedAt`.
    ///   - taskID: The task the hub filed it for, read from the body's `taskId`, which schema 1 does not define.
    init(from dto: ConversationBodyDTO, id: Conversation.ID, modifiedAt: Date, taskID: ScheduledTask.ID? = nil) throws {
        self.init(
            id: id,
            title: dto.title ?? "",
            modelID: dto.modelId.map { ChatModel.ID($0) },
            messages: try (dto.messages ?? []).map(Message.init(from:)),
            isPinned: dto.isPinned ?? false,
            isPrivate: false,
            projectID: dto.projectId.flatMap { UUID(uuidString: $0) }.map { Project.ID($0) },
            taskID: taskID,
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

public extension ScheduledTask.ID {
    /// The task a received conversation body names in its `taskId`; `nil` when it names none, or one that is not a
    /// UUID, which no app makes.
    init?(referencedBy body: JSONValue) {
        guard let text = body.objectValue?[SyncWire.taskReferenceField]?.stringValue, let uuid = UUID(uuidString: text) else {
            return nil
        }
        self.init(uuid)
    }
}

// MARK: - To the wire

public extension Conversation {
    /// The body to sync, with the task it was filed for written back as `taskId`, so that it is not lost even when
    /// the fields kept from the hub's copy have been forgotten.
    func syncBody() throws -> JSONValue {
        let written = try SyncWire.json(from: ConversationBodyDTO(from: self))
        guard let taskID, var members = written.objectValue else {
            return written
        }
        members[SyncWire.taskReferenceField] = .string(taskID.rawValue.uuidString.lowercased())
        return .object(members)
    }
}

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
