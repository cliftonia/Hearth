import Foundation
import HearthDomain

// The sync page: where the hub is, its token, the switch, and syncing now. Each takes effect at once, like the
// notification switches; none of it is part of the draft that Done keeps.
extension SettingsPresenter {
    /// What the sync page is built from.
    struct SyncControls {
        let store: SyncStore
        /// Runs a sync now and returns when it is done.
        let syncNow: @MainActor () async -> Void
        /// Checks the hub at an address, with a token or none.
        let check: @MainActor (URL, String?) async -> SyncHubCheckKind
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

    /// Keeps the address as typed. With no usable address, sync is turned off.
    func syncAddressAction() {
        let address = viewModel.syncAddress.trimmingCharacters(in: .whitespaces)
        let isEnabled = viewModel.isSyncEnabled && SyncSettings(hubAddress: address).hubURL != nil
        viewModel.isSyncEnabled = isEnabled
        let settings = SyncSettings(hubAddress: address, isEnabled: isEnabled)
        guard settings != syncStore.settings else {
            return
        }
        syncStore.update(settings)
        viewModel.syncCheck = .idle
    }

    /// Keeps the switch as it now stands, and syncs at once when it is turned on.
    func syncEnabledAction() async {
        let wasEnabled = syncStore.settings.isEnabled
        // Keeping the address keeps the switch with it, or turns it back off when there is no address.
        syncAddressAction()
        if syncStore.settings.isEnabled, !wasEnabled {
            await dependencies.sync.syncNow()
        }
    }

    /// Saves the typed token in the Keychain and empties the field.
    func saveSyncTokenAction() {
        let token = viewModel.syncTokenDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            return
        }
        keepToken(token)
    }

    /// Forgets the saved token.
    func removeSyncTokenAction() {
        keepToken(nil)
    }

    func syncNowAction() async {
        syncAddressAction()
        saveSyncTokenAction()
        await dependencies.sync.syncNow()
    }

    /// Checks that the hub at the typed address answers and lets this device in.
    func checkHubAction() async {
        syncAddressAction()
        saveSyncTokenAction()
        guard let url = syncStore.settings.hubURL else {
            viewModel.syncCheck = .failed(message: Strings.syncFailedNotConfigured)
            return
        }
        viewModel.syncCheck = .checking
        switch await dependencies.sync.check(url, syncStore.token()) {
        case .reachable:
            viewModel.syncCheck = .succeeded
        case .failed(let failure):
            viewModel.syncCheck = .failed(message: Self.words(for: failure))
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

    private func keepToken(_ token: String?) {
        do {
            try syncStore.setToken(token)
            viewModel.syncTokenDraft = ""
            viewModel.syncCheck = .idle
        } catch {
            logger.error("Keeping the hub token failed")
        }
    }
}
