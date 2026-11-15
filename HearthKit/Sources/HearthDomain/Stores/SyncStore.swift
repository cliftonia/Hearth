import Foundation
import HearthCore
import Observation
import os

/// Sync's settings, how the last sync went, and the journal it keeps: shared by the sync page in the settings and by
/// whatever runs the syncs. None of it is ever synced.
@MainActor
@Observable
public final class SyncStore {
    public private(set) var settings: SyncSettings
    /// Whether an access token is saved. The token itself is read from the Keychain only when it is sent.
    public private(set) var hasToken: Bool
    public private(set) var isSyncing = false
    /// Why the last sync did not finish; `nil` after one that did.
    public private(set) var failure: SyncFailureKind?
    public private(set) var journal: SyncJournal

    /// When the last sync finished.
    public var lastSyncedAt: Date? { journal.lastSyncedAt }

    private let provider: SyncStoreProvider
    private let clock: @MainActor () -> Date
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    private let logger = Logger(for: SyncStore.self)

    /// Reads the settings and the journal at once, so that a change made at launch is recorded in the journal
    /// that is already there.
    ///
    /// - Parameter defaultHubAddress: The hub the page offers until the user saves one of their own. It only fills in
    ///   the address; sync stays off until it is turned on.
    public init(provider: SyncStoreProvider, defaultHubAddress: String = "", clock: @escaping @MainActor () -> Date = { Date() }) {
        self.provider = provider
        self.clock = clock
        let saved = provider.loadSettings().flatMap { try? JSONDecoder().decode(SyncSettings.self, from: $0) }
        self.settings = saved ?? SyncSettings(hubAddress: defaultHubAddress)
        self.hasToken = ((try? provider.readToken()) ?? nil) != nil
        self.journal = provider.loadJournal().flatMap { try? JSONDecoder().decode(SyncJournal.self, from: $0) } ?? SyncJournal()
    }

    // MARK: Settings

    /// Keeps new settings. Pointing at another hub forgets what was known of the last one.
    public func update(_ settings: SyncSettings) {
        if settings.hubURL != self.settings.hubURL {
            journal.forgetHub()
            failure = nil
            persistJournal()
        }
        self.settings = settings
        provider.saveSettings(try? JSONEncoder().encode(settings))
    }

    /// The access token, read from the Keychain; `nil` when none is saved or it cannot be read.
    public func token() -> String? {
        do {
            return try provider.readToken()
        } catch {
            logger.error("Reading the hub token failed")
            return nil
        }
    }

    /// Keeps a new access token, or forgets it with `nil` or an empty one.
    public func setToken(_ token: String?) throws {
        let token = token?.trimmingCharacters(in: .whitespacesAndNewlines)
        try provider.writeToken(token?.isEmpty == false ? token : nil)
        hasToken = token?.isEmpty == false
    }

    // MARK: Changes made here

    /// Notes a change made on this device. A deletion is kept as a tombstone until the hub takes it.
    public func record(_ change: SyncLocalChangeKind) {
        switch change {
        case .changed:
            break
        case .deleted(let key, let date):
            journal.tombstones[key] = SyncStamp(date: date, writer: journal.installID)
            journal.unknownFields[key] = nil
            persistJournal()
        }
    }

    // MARK: Running a sync

    /// Changes the journal in memory; `persistJournal()` writes it.
    public func updateJournal(_ change: (inout SyncJournal) -> Void) {
        change(&journal)
    }

    /// Writes the journal as it now stands. Writes happen one after another, in the order they were asked for.
    public func persistJournal() {
        let data = try? JSONEncoder().encode(journal)
        let previous = saveTask
        let provider = provider
        let logger = logger
        saveTask = Task {
            await previous?.value
            do {
                try await provider.saveJournal(data)
            } catch {
                logger.error("Saving the sync journal failed")
            }
        }
    }

    /// Waits until every write asked for so far is done.
    public func flush() async {
        await saveTask?.value
    }

    public func syncDidBegin() {
        isSyncing = true
    }

    /// Records how a sync ended: finished, with nothing wrong or with some items too large, or failed.
    public func syncDidEnd(failure: SyncFailureKind?, finished: Bool) {
        isSyncing = false
        self.failure = failure
        if finished {
            journal.lastSyncedAt = clock()
        }
        persistJournal()
    }

    // MARK: Erasing

    /// Turns sync off and forgets everything about it on this device: the hub's address, the token, and the
    /// journal, deletions not yet sent included. Nothing is sent to the hub.
    public func reset() async {
        settings = SyncSettings()
        provider.saveSettings(nil)
        do {
            try provider.writeToken(nil)
        } catch {
            logger.error("Forgetting the hub token failed")
        }
        hasToken = false
        failure = nil
        isSyncing = false
        journal = SyncJournal()
        await flush()
        do {
            try await provider.saveJournal(nil)
        } catch {
            logger.error("Removing the sync journal failed")
        }
    }
}
