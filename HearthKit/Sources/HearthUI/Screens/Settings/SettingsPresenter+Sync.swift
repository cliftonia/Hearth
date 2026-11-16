import Foundation
import HearthDomain

// The sync page: where the hub is, its access key, the switch, and syncing now. Each takes effect at once, and is
// kept in the sync store rather than with the other settings. The access key is still called a token in code and in
// what is stored, so that a key saved by an earlier version is found.
extension SettingsPresenter {
    /// What the sync page is built from.
    struct SyncControls {
        let store: SyncStore
        /// Runs a sync now and returns when it is done.
        let syncNow: @MainActor () async -> Void
        /// Checks the hub at an address, with a token or none.
        let check: @MainActor (URL, String?) async -> SyncHubCheckKind
        /// Tells whatever runs the syncs that the address, the token or the switch changed, so that it starts or
        /// stops its regular passes to match.
        let settingsChanged: @MainActor () -> Void
    }

    var syncStore: SyncStore { dependencies.sync.store }

    /// Whether the switch can be turned on: only with an address to sync with.
    var canEnableSync: Bool { SyncSettings(hubAddress: viewModel.syncAddress).hubURL != nil }

    /// Fills the page from what is saved. The token is never read into it.
    func loadSyncAction() {
        viewModel.syncAddress = syncStore.settings.hubAddress
        viewModel.isSyncEnabled = syncStore.settings.isEnabled
        viewModel.syncTokenDraft = ""
        viewModel.syncCheck = .idle
    }

    /// Keeps the address as typed. A new address, or none, is synced with at once while sync is on.
    func syncAddressAction() async {
        if keepSyncSettings() {
            await syncSettingsDidChange()
        }
    }

    /// Keeps the switch as it now stands, and syncs at once when it is turned on.
    func syncEnabledAction() async {
        // Keeping the address keeps the switch with it, or turns it back off when there is no address.
        if keepSyncSettings() {
            await syncSettingsDidChange()
        }
    }

    /// Saves the typed token in the Keychain, empties the field, and syncs with it at once while sync is on. The typed
    /// address is kept first, so that the token is saved for the hub it was typed for, and is not forgotten when that
    /// address is kept later.
    func saveSyncTokenAction() async {
        keepSyncSettings()
        if keepTypedToken() {
            await syncSettingsDidChange()
        }
    }

    /// Forgets the saved token.
    func removeSyncTokenAction() {
        keepToken(nil)
    }

    func syncNowAction() async {
        keepSyncSettings()
        keepTypedToken()
        dependencies.sync.settingsChanged()
        await dependencies.sync.syncNow()
    }

    /// Checks that the hub at the typed address answers and lets this device in.
    func checkHubAction() async {
        keepSyncSettings()
        keepTypedToken()
        guard let url = syncStore.settings.hubURL else {
            viewModel.syncCheck = .failed(message: Strings.syncFailedNotConfigured)
            dependencies.announce(Strings.syncFailedNotConfigured)
            return
        }
        viewModel.syncCheck = .checking
        switch await dependencies.sync.check(url, syncStore.token()) {
        case .reachable:
            viewModel.syncCheck = .succeeded
            dependencies.announce(Strings.syncCheckSucceeded)
        case .failed(let failure):
            let message = Self.words(for: failure)
            viewModel.syncCheck = .failed(message: message)
            dependencies.announce(message)
        }
    }

    /// The status line: syncing, the last error in plain words, when it last synced, or that it has not.
    var syncStatusText: String {
        let store = syncStore
        if store.isSyncing {
            return Strings.syncInProgress
        }
        if let failure = store.failure {
            return Self.words(for: failure)
        }
        if let date = store.lastSyncedAt {
            return Strings.syncLastSynced(when: date.formatted(date: .abbreviated, time: .shortened))
        }
        return Strings.syncNever
    }

    /// A failure in words the user can act on.
    static func words(for failure: SyncFailureKind) -> String {
        switch failure {
        case .notConfigured:
            Strings.syncFailedNotConfigured
        case .unreachable:
            Strings.syncFailedUnreachable
        case .tokenNeeded:
            Strings.syncFailedTokenNeeded
        case .tokenRefused:
            Strings.syncFailedTokenRefused
        case .hubFailed(let status):
            Strings.syncFailedHub(number: status)
        case .unreadable:
            Strings.syncFailedUnreadable
        case .tooLarge(let count):
            Strings.syncTooLarge(number: count)
        }
    }

    /// Keeps the address and the switch as they stand in the form; with no usable address, sync is turned off.
    /// Returns whether anything changed.
    @discardableResult
    private func keepSyncSettings() -> Bool {
        let address = viewModel.syncAddress.trimmingCharacters(in: .whitespaces)
        let isEnabled = viewModel.isSyncEnabled && SyncSettings(hubAddress: address).hubURL != nil
        viewModel.isSyncEnabled = isEnabled
        let settings = SyncSettings(hubAddress: address, isEnabled: isEnabled)
        guard settings != syncStore.settings else {
            return false
        }
        syncStore.update(settings)
        viewModel.syncCheck = .idle
        return true
    }

    /// Keeps the token typed in the form, if one was. Returns whether one was kept.
    @discardableResult
    private func keepTypedToken() -> Bool {
        let token = viewModel.syncTokenDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            return false
        }
        return keepToken(token)
    }

    /// Starts or stops the regular passes to match the new settings, and syncs at once if sync is on.
    private func syncSettingsDidChange() async {
        dependencies.sync.settingsChanged()
        if syncStore.settings.isEnabled {
            await dependencies.sync.syncNow()
        }
    }

    @discardableResult
    private func keepToken(_ token: String?) -> Bool {
        do {
            try syncStore.setToken(token)
            viewModel.syncTokenDraft = ""
            viewModel.syncCheck = .idle
            return true
        } catch {
            logger.error("Keeping the hub token failed")
            return false
        }
    }
}
