import Foundation
import HearthData

/// How the domain reads and writes saved projects.
public struct ProjectDataProvider: Sendable {
    public let loadAll: @Sendable () async throws -> [Project]
    public let save: @Sendable (Project) async throws -> Void
    public let delete: @Sendable (Project.ID) async throws -> Void
    /// Removes everything saved at once, including anything that can no longer be read. Without it, each is removed in turn.
    public let deleteAll: (@Sendable () async throws -> Void)?

    public init(
        loadAll: @escaping @Sendable () async throws -> [Project],
        save: @escaping @Sendable (Project) async throws -> Void,
        delete: @escaping @Sendable (Project.ID) async throws -> Void,
        deleteAll: (@Sendable () async throws -> Void)? = nil
    ) {
        self.loadAll = loadAll
        self.save = save
        self.delete = delete
        self.deleteAll = deleteAll
    }
}

public extension ProjectDataProvider {
    /// Projects kept as one JSON file each, in a folder of their own, on the device only.
    static func live(service: FileStoreService = FileStoreService(directoryName: "Projects")) -> ProjectDataProvider {
        ProjectDataProvider(
            loadAll: {
                // A file that no longer decodes is skipped rather than hiding every other project.
                try await service.loadAll().compactMap { try? JSONDecoder().decode(Project.self, from: $0) }
            },
            save: { project in
                try await service.save(try JSONEncoder().encode(project), name: fileName(for: project.id))
            },
            delete: { id in
                try await service.delete(name: fileName(for: id))
            },
            deleteAll: {
                try await service.deleteAll()
            }
        )
    }

    private static func fileName(for id: Project.ID) -> String {
        "\(id.rawValue.uuidString).json"
    }
}
