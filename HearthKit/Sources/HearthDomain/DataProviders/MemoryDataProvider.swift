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
                return try JSONDecoder().decode([Memory].self, from: data)
            },
            save: { memories in
                try await service.save(try JSONEncoder().encode(memories), name: "memories.json")
            }
        )
    }
}
