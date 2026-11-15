import Foundation
import HearthData

/// How the domain talks to a Hearth Hub.
public struct SyncDataProvider: Sendable {
    /// Whether the hub at the address answers, and the name of its database. Needs no token.
    public let health: @Sendable (URL) async throws -> SyncHealthDTO
    /// One page of changes after the cursor, with the token if there is one.
    public let changes: @Sendable (URL, String?, Int) async throws -> SyncChangesDTO
    /// Stores one item or deletion on the hub, with the token if there is one.
    public let put: @Sendable (URL, String?, SyncItemKey, SyncPutDTO) async throws -> SyncPutResultDTO

    public init(
        health: @escaping @Sendable (URL) async throws -> SyncHealthDTO,
        changes: @escaping @Sendable (URL, String?, Int) async throws -> SyncChangesDTO,
        put: @escaping @Sendable (URL, String?, SyncItemKey, SyncPutDTO) async throws -> SyncPutResultDTO
    ) {
        self.health = health
        self.changes = changes
        self.put = put
    }
}

public extension SyncDataProvider {
    /// The number of changes asked for at once.
    static let pageSize = 200

    static func live(service: SyncService = SyncService()) -> SyncDataProvider {
        SyncDataProvider(
            health: { try await service.health(baseURL: $0) },
            changes: { url, token, since in
                try await service.changes(baseURL: url, token: token, since: since, limit: pageSize)
            },
            put: { url, token, key, change in
                try await service.put(baseURL: url, token: token, kind: key.kind.rawValue, id: key.id, change: change)
            }
        )
    }
}

/// Where sync keeps what it remembers on this device: its settings, its journal and the hub's access token.
public struct SyncStoreProvider: Sendable {
    public let loadSettings: @Sendable () -> Data?
    public let saveSettings: @Sendable (Data?) -> Void
    /// The journal as last saved, read at once so that no change made at launch is recorded before it.
    public let loadJournal: @Sendable () -> Data?
    /// Writes the journal, or removes it when given `nil`.
    public let saveJournal: @Sendable (Data?) async throws -> Void
    public let readToken: @Sendable () throws -> String?
    /// Keeps the token, or forgets it when given `nil`.
    public let writeToken: @Sendable (String?) throws -> Void

    public init(
        loadSettings: @escaping @Sendable () -> Data?,
        saveSettings: @escaping @Sendable (Data?) -> Void,
        loadJournal: @escaping @Sendable () -> Data?,
        saveJournal: @escaping @Sendable (Data?) async throws -> Void,
        readToken: @escaping @Sendable () throws -> String?,
        writeToken: @escaping @Sendable (String?) throws -> Void
    ) {
        self.loadSettings = loadSettings
        self.saveSettings = saveSettings
        self.loadJournal = loadJournal
        self.saveJournal = saveJournal
        self.readToken = readToken
        self.writeToken = writeToken
    }
}

public extension SyncStoreProvider {
    /// The settings in the user defaults, the journal in a `Sync` folder beside `Conversations`, and the token in
    /// the Keychain, on this device only.
    static func live(
        files: FileStoreService = FileStoreService(directoryName: "Sync"),
        keychain: KeychainService = KeychainService(service: "Hearth.sync", account: "hubToken")
    ) -> SyncStoreProvider {
        let settingsKey = "syncSettings"
        let journalName = "journal.json"
        return SyncStoreProvider(
            loadSettings: { UserDefaults.standard.data(forKey: settingsKey) },
            saveSettings: { data in
                if let data {
                    UserDefaults.standard.set(data, forKey: settingsKey)
                } else {
                    UserDefaults.standard.removeObject(forKey: settingsKey)
                }
            },
            loadJournal: { files.loadNow(name: journalName) },
            saveJournal: { data in
                if let data {
                    try await files.save(data, name: journalName)
                } else {
                    try await files.delete(name: journalName)
                }
            },
            readToken: { try keychain.read() },
            writeToken: { token in
                if let token {
                    try keychain.write(token)
                } else {
                    try keychain.delete()
                }
            }
        )
    }
}
