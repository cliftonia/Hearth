import Foundation
import HearthCore
import HearthData

/// How the domain reads and writes saved conversations.
public typealias ConversationDataProvider = SavedItemDataProvider<Conversation>

/// How the domain reads and writes saved projects.
public typealias ProjectDataProvider = SavedItemDataProvider<Project>

/// How the domain reads and writes saved scheduled tasks.
public typealias TaskDataProvider = SavedItemDataProvider<ScheduledTask>

/// How the domain reads and writes one kind of thing kept on the device: conversations, projects or tasks.
public struct SavedItemDataProvider<Item: Identifiable & Codable & Sendable>: Sendable where Item.ID: Sendable {
    public let loadAll: @Sendable () async throws -> [Item]
    public let save: @Sendable (Item) async throws -> Void
    public let delete: @Sendable (Item.ID) async throws -> Void
    /// Removes everything saved at once, including anything that can no longer be read.
    public let deleteAll: @Sendable () async throws -> Void

    public init(
        loadAll: @escaping @Sendable () async throws -> [Item],
        save: @escaping @Sendable (Item) async throws -> Void,
        delete: @escaping @Sendable (Item.ID) async throws -> Void,
        deleteAll: @escaping @Sendable () async throws -> Void
    ) {
        self.loadAll = loadAll
        self.save = save
        self.delete = delete
        self.deleteAll = deleteAll
    }
}

public extension SavedItemDataProvider where Item == Conversation {
    /// Conversations kept as one JSON file each, on the device only.
    static func live(service: FileStoreService = FileStoreService(directoryName: "Conversations")) -> ConversationDataProvider {
        files(in: service)
    }
}

public extension SavedItemDataProvider where Item == Project {
    /// Projects kept as one JSON file each, in a folder of their own, on the device only.
    static func live(service: FileStoreService = FileStoreService(directoryName: "Projects")) -> ProjectDataProvider {
        files(in: service)
    }
}

public extension SavedItemDataProvider where Item == ScheduledTask {
    /// Scheduled tasks kept as one JSON file each, in a folder of their own: this device's copy of what the hub holds.
    static func live(service: FileStoreService = FileStoreService(directoryName: "Tasks")) -> TaskDataProvider {
        files(in: service)
    }
}

extension SavedItemDataProvider where Item.ID == Tagged<Item, UUID> {
    /// Each item kept as a JSON file named after its identifier, in the service's folder.
    static func files(in service: FileStoreService) -> SavedItemDataProvider {
        SavedItemDataProvider(
            loadAll: {
                // A file that no longer decodes is skipped rather than hiding every other item.
                try await service.loadAll().compactMap { try? JSONDecoder().decode(Item.self, from: $0) }
            },
            save: { item in
                try await service.save(try JSONEncoder().encode(item), name: fileName(for: item.id))
            },
            delete: { id in
                try await service.delete(name: fileName(for: id))
            },
            deleteAll: {
                try await service.deleteAll()
            }
        )
    }

    private static func fileName(for id: Item.ID) -> String {
        "\(id.rawValue.uuidString).json"
    }
}
