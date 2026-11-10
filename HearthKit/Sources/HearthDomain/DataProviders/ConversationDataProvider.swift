import Foundation
import HearthData

public struct ConversationDataProvider: Sendable {
    public let loadAll: @Sendable () async throws -> [Conversation]
    public let save: @Sendable (Conversation) async throws -> Void
    public let delete: @Sendable (Conversation.ID) async throws -> Void

    public init(
        loadAll: @escaping @Sendable () async throws -> [Conversation],
        save: @escaping @Sendable (Conversation) async throws -> Void,
        delete: @escaping @Sendable (Conversation.ID) async throws -> Void
    ) {
        self.loadAll = loadAll
        self.save = save
        self.delete = delete
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
            }
        )
    }

    private static func fileName(for id: Conversation.ID) -> String {
        "\(id.rawValue.uuidString).json"
    }
}
