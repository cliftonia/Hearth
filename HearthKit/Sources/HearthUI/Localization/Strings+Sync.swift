import Foundation

// The sync page in the settings, and the status line it shows.
// swiftlint:disable line_length
extension Strings {
    static let sync = String(localized: "sync.title", defaultValue: "Sync", bundle: .module)
    static let syncOn = String(localized: "sync.on", defaultValue: "On", bundle: .module)
    static let syncOff = String(localized: "sync.off", defaultValue: "Off", bundle: .module)
    static let syncHubAddress = String(localized: "sync.hubAddress", defaultValue: "Hub address", bundle: .module)
    static let syncHubFooter = String(localized: "sync.hubFooter", defaultValue: "Your own Hearth Hub keeps your chats, projects and memories in step between your devices. Private chats, settings, server addresses and your profile are never synced.", bundle: .module)
    static let syncToken = String(localized: "sync.token", defaultValue: "Access token", bundle: .module)
    static let syncTokenPlaceholder = String(localized: "sync.tokenPlaceholder", defaultValue: "Optional", bundle: .module)
    static let syncTokenSavedPlaceholder = String(localized: "sync.tokenSavedPlaceholder", defaultValue: "Saved. Type a new one to replace it", bundle: .module)
    static let syncTokenFooter = String(localized: "sync.tokenFooter", defaultValue: "Only if your hub asks for one. It is kept in this device's Keychain and is never synced.", bundle: .module)
    static let syncSaveToken = String(localized: "sync.saveToken", defaultValue: "Save token", bundle: .module)
    static let syncRemoveToken = String(localized: "sync.removeToken", defaultValue: "Remove token", bundle: .module)
    static let syncSwitch = String(localized: "sync.switch", defaultValue: "Sync this device", bundle: .module)
    static let syncSwitchDetail = String(localized: "sync.switchDetail", defaultValue: "When Hearth opens, when it comes back, and shortly after a change.", bundle: .module)
    static let syncNeedsAddress = String(localized: "sync.needsAddress", defaultValue: "Add the hub's address to turn sync on.", bundle: .module)
    static let syncNow = String(localized: "sync.now", defaultValue: "Sync now", bundle: .module)
    static let syncCheck = String(localized: "sync.check", defaultValue: "Test connection", bundle: .module)
    static let syncCheckSucceeded = String(localized: "sync.checkSucceeded", defaultValue: "Connected to the hub.", bundle: .module)
    static let syncStatus = String(localized: "sync.status", defaultValue: "Status", bundle: .module)
    static let syncInProgress = String(localized: "sync.inProgress", defaultValue: "Syncing…", bundle: .module)
    static let syncNever = String(localized: "sync.never", defaultValue: "Not synced yet.", bundle: .module)
    static let syncFailedNotConfigured = String(localized: "sync.failed.notConfigured", defaultValue: "The hub address is not a usable address.", bundle: .module)
    static let syncFailedUnreachable = String(localized: "sync.failed.unreachable", defaultValue: "The hub could not be reached. Hearth will try again later.", bundle: .module)
    static let syncFailedTokenNeeded = String(localized: "sync.failed.tokenNeeded", defaultValue: "The hub needs an access token.", bundle: .module)
    static let syncFailedTokenRefused = String(localized: "sync.failed.tokenRefused", defaultValue: "The hub did not accept the access token.", bundle: .module)
    static let syncFailedUnreadable = String(localized: "sync.failed.unreadable", defaultValue: "The hub's answer could not be read. Is this the address of a Hearth Hub?", bundle: .module)

    static func syncLastSynced(when: String) -> String {
        String(localized: "sync.lastSynced", defaultValue: "Last synced \(when).", bundle: .module)
    }

    static func syncFailedHub(number: Int) -> String {
        String(localized: "sync.failed.hub", defaultValue: "The hub ran into a problem (\(number)). Hearth will try again later.", bundle: .module)
    }

    static func syncTooLarge(number: Int) -> String {
        String(localized: "sync.tooLarge", defaultValue: "Synced, except \(number) too large for the hub, which stay on this device only.", bundle: .module)
    }
}
// swiftlint:enable line_length
