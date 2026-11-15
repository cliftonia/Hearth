import Foundation
import HearthData

/// How the domain reads and writes what is remembered about the user.
public struct MemoryDataProvider: Sendable {
    public let load: @Sendable () async throws -> [Memory]
    public let save: @Sendable ([Memory]) async throws -> Void

    public init(load: @escaping @Sendable () async throws -> [Memory], save: @escaping @Sendable ([Memory]) async throws -> Void) {
        self.load = load
        self.save = save
    }
}

public extension MemoryDataProvider {
    /// Memories kept as one JSON file, on the device only.
    static func live(service: FileStoreService = FileStoreService(directoryName: "Memory")) -> MemoryDataProvider {
        MemoryDataProvider(
            load: {
                guard let data = try await service.loadAll().first else {
                    return []
                }
                let memories = try JSONDecoder().decode([Memory].self, from: data)
                // Memories saved before sync were each just given a new `syncID`; it is written back at once, so
                // that the next launch reads the same one.
                if try JSONDecoder().decode([SyncIDProbe].self, from: data).contains(where: { $0.syncID == nil }) {
                    try await service.save(try JSONEncoder().encode(memories), name: fileName)
                }
                return memories
            },
            save: { memories in
                try await service.save(try JSONEncoder().encode(memories), name: fileName)
            }
        )
    }

    private static let fileName = "memories.json"

    /// Whether a saved memory already has its identifier for sync.
    private struct SyncIDProbe: Decodable {
        let syncID: UUID?
    }
}
