import Foundation
import HearthData

/// How the domain reads and writes saved conversations.
public struct ConversationDataProvider: Sendable {
    public let loadAll: @Sendable () async throws -> [Conversation]
    public let save: @Sendable (Conversation) async throws -> Void
    public let delete: @Sendable (Conversation.ID) async throws -> Void
    /// Removes everything saved at once, including anything that can no longer be read. Without it, each is removed in turn.
    public let deleteAll: (@Sendable () async throws -> Void)?

    public init(
        loadAll: @escaping @Sendable () async throws -> [Conversation],
        save: @escaping @Sendable (Conversation) async throws -> Void,
        delete: @escaping @Sendable (Conversation.ID) async throws -> Void,
        deleteAll: (@Sendable () async throws -> Void)? = nil
    ) {
        self.loadAll = loadAll
        self.save = save
        self.delete = delete
        self.deleteAll = deleteAll
    }
}

public extension ConversationDataProvider {
    /// Conversations kept as one JSON file each, on the device only.
    static func live(service: FileStoreService = FileStoreService(directoryName: "Conversations")) -> ConversationDataProvider {
        ConversationDataProvider(
            loadAll: {
                // A file that no longer decodes is skipped rather than hiding every other conversation.
                try await service.loadAll().compactMap { try? JSONDecoder().decode(Conversation.self, from: $0) }
            },
            save: { conversation in
                try await service.save(try JSONEncoder().encode(conversation), name: fileName(for: conversation.id))
            },
            delete: { id in
                try await service.delete(name: fileName(for: id))
            },
            deleteAll: {
                try await service.deleteAll()
            }
        )
    }

    private static func fileName(for id: Conversation.ID) -> String {
        "\(id.rawValue.uuidString).json"
    }
}
