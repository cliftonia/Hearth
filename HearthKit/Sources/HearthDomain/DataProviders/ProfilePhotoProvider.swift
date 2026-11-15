import Foundation
import HearthData

/// How the domain reads and writes the user's profile photo.
public struct ProfilePhotoProvider: Sendable {
    /// The saved photo as JPEG data; `nil` when there is none.
    public let load: @Sendable () async throws -> Data?
    public let save: @Sendable (Data) async throws -> Void
    /// Removes the photo. Removing one that is not there is not an error.
    public let delete: @Sendable () async throws -> Void

    public init(
        load: @escaping @Sendable () async throws -> Data?,
        save: @escaping @Sendable (Data) async throws -> Void,
        delete: @escaping @Sendable () async throws -> Void
    ) {
        self.load = load
        self.save = save
        self.delete = delete
    }
}

public extension ProfilePhotoProvider {
    /// The photo kept as one small file in a folder of its own, on the device only.
    static func live(service: FileStoreService = FileStoreService(directoryName: "Profile")) -> ProfilePhotoProvider {
        ProfilePhotoProvider(
            load: { try await service.loadAll().first },
            save: { try await service.save($0, name: "photo.jpg") },
            delete: { try await service.deleteAll() }
        )
    }
}
