import Foundation

/// Keeps named blobs as files in one directory under Application Support.
public struct FileStoreService: Sendable {
    private let directoryURL: URL

    public init(directoryURL: URL) {
        self.directoryURL = directoryURL
    }

    /// Keeps the files in a directory of the given name under Application Support.
    public init(directoryName: String) {
        self.init(directoryURL: URL.applicationSupportDirectory.appending(path: directoryName, directoryHint: .isDirectory))
    }

    /// Writes the blob under the given name, replacing any already there. The directory is made if it is missing.
    public func save(_ data: Data, name: String) async throws {
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try data.write(to: directoryURL.appending(path: name), options: .atomic)
    }

    /// Every blob in the directory, in no particular order; none when the directory does not exist yet.
    public func loadAll() async throws -> [Data] {
        let manager = FileManager.default
        guard manager.fileExists(atPath: directoryURL.path(percentEncoded: false)) else {
            return []
        }
        return try manager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)
            .map { try Data(contentsOf: $0) }
    }

    /// Removes the named blob. Deleting one that is not there is not an error.
    public func delete(name: String) async throws {
        let fileURL = directoryURL.appending(path: name)
        guard FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false)) else {
            return
        }
        try FileManager.default.removeItem(at: fileURL)
    }
}
