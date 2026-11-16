// Stand-ins for taking the README's pictures in the simulator: a server that lists a few models and answers with a
// fixed line, a hub that keeps whatever it is sent, and stores that start with tidy sample data. They are compiled into
// debug builds for the simulator only, and never into a build that ships.
#if DEBUG && targetEnvironment(simulator)
import Foundation
import HearthData
import os

public extension ChatDataProvider {
    /// A chat server that lists the given models and answers anything with one short line, asking no real server.
    static func screenshots(models: [ChatModel]) -> ChatDataProvider {
        ChatDataProvider(
            fetchModels: { _ in models },
            streamChat: { _, _ in
                AsyncThrowingStream { continuation in
                    continuation.yield(.text("This is a sample reply."))
                    continuation.finish()
                }
            },
            complete: { _, _ in "" }
        )
    }
}

public extension SyncDataProvider {
    /// A hub that answers, has nothing new, and keeps every item it is sent.
    static var screenshots: SyncDataProvider {
        let hubID = "sample-hub"
        return SyncDataProvider(
            health: { _ in SyncHealthDTO(ok: true, seq: 1, hubId: hubID, authRequired: true) },
            changes: { _, _, since in SyncChangesDTO(hubId: hubID, items: [], next: max(since, 1), hasMore: false) },
            put: { _, _, key, change in
                .accepted(SyncEnvelopeDTO(
                    kind: key.kind.rawValue,
                    id: key.id,
                    updatedAt: change.updatedAt,
                    updatedBy: change.updatedBy,
                    deleted: change.deleted,
                    body: change.body,
                    seq: 1
                ))
            }
        )
    }
}

public extension SyncStoreProvider {
    /// Sync's settings, journal and token held in memory only, starting with sync on and a key saved.
    static func screenshots(settings: SyncSettings) -> SyncStoreProvider {
        let state = OSAllocatedUnfairLock(initialState: ScreenshotSyncState(
            settings: try? JSONEncoder().encode(settings),
            token: "sample-key"
        ))
        return SyncStoreProvider(
            loadSettings: { state.withLock { $0.settings } },
            saveSettings: { data in state.withLock { $0.settings = data } },
            loadJournal: { state.withLock { $0.journal } },
            saveJournal: { data in state.withLock { $0.journal = data } },
            readToken: { state.withLock { $0.token } },
            writeToken: { token in state.withLock { $0.token = token } }
        )
    }
}

public extension SavedItemDataProvider {
    /// The given store, filled with the samples the first time it is read empty.
    static func seeded(_ store: SavedItemDataProvider, with samples: [Item]) -> SavedItemDataProvider {
        SavedItemDataProvider(
            loadAll: {
                let saved = try await store.loadAll()
                guard saved.isEmpty else {
                    return saved
                }
                for sample in samples {
                    try await store.save(sample)
                }
                return samples
            },
            save: store.save,
            delete: store.delete,
            deleteAll: store.deleteAll
        )
    }
}

public extension MemoryDataProvider {
    /// The given store, filled with the samples the first time it is read empty.
    static func seeded(_ store: MemoryDataProvider, with samples: [Memory]) -> MemoryDataProvider {
        MemoryDataProvider(
            load: {
                let saved = try await store.load()
                guard saved.isEmpty else {
                    return saved
                }
                try await store.save(samples)
                return samples
            },
            save: store.save
        )
    }
}

/// What the stand-in for sync's own storage holds.
private struct ScreenshotSyncState: Sendable {
    var settings: Data?
    var journal: Data?
    var token: String?
}
#endif
