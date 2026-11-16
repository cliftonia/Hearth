import Foundation

// The main list of the settings: its sections, what each row says about where it leads, and the lock's wording.
// swiftlint:disable line_length
extension Strings {
    static let settingsChats = String(localized: "settings.section.chats", defaultValue: "Chats", bundle: .module)
    static let settingsVoicePictures = String(localized: "settings.section.voicePictures", defaultValue: "Voice & Pictures", bundle: .module)
    static let settingsAppearancePrivacy = String(localized: "settings.section.appearancePrivacy", defaultValue: "Appearance & Privacy", bundle: .module)
    static let settingsServersSync = String(localized: "settings.section.serversSync", defaultValue: "Servers & Sync", bundle: .module)
    static let settingsOn = String(localized: "settings.on", defaultValue: "On", bundle: .module)
    static let settingsOff = String(localized: "settings.off", defaultValue: "Off", bundle: .module)

    static let webSearchReadsPages = String(localized: "settings.webSearch.readsPages", defaultValue: "Reads full pages", bundle: .module)
    static let webSearchSnippetsOnly = String(localized: "settings.webSearch.snippetsOnly", defaultValue: "Snippets only", bundle: .module)
    static let tasksNone = String(localized: "settings.tasks.none", defaultValue: "None", bundle: .module)
    static let tasksNeedsSync = String(localized: "settings.tasks.needsSync", defaultValue: "Needs sync", bundle: .module)
    static let voiceNeedsServer = String(localized: "settings.voice.needsServer", defaultValue: "Needs a speech server", bundle: .module)
    static let serversNotConnected = String(localized: "settings.servers.notConnected", defaultValue: "Not connected", bundle: .module)
    static let serversNotChecked = String(localized: "settings.servers.notChecked", defaultValue: "Not checked", bundle: .module)
    static let vibration = String(localized: "settings.vibration", defaultValue: "Vibration", bundle: .module)

    static func memoryOn(number: Int) -> String {
        String(localized: "settings.memory.on", defaultValue: "On · \(number) saved", bundle: .module)
    }

    static func tasksActive(number: Int) -> String {
        String(localized: "settings.tasks.active", defaultValue: "\(number) active", bundle: .module)
    }

    static func voiceReadsAloud(voice: String) -> String {
        String(localized: "settings.voice.readsAloud", defaultValue: "\(voice) · reads aloud", bundle: .module)
    }

    static func syncOnSynced(when: String) -> String {
        String(localized: "settings.sync.onSynced", defaultValue: "On · synced \(when)", bundle: .module)
    }

    // MARK: The lock, named for how the device unlocks

    static let biometryFaceID = String(localized: "lock.biometry.faceID", defaultValue: "Face ID", bundle: .module)
    static let biometryTouchID = String(localized: "lock.biometry.touchID", defaultValue: "Touch ID", bundle: .module)
    static let biometryOpticID = String(localized: "lock.biometry.opticID", defaultValue: "Optic ID", bundle: .module)
    static let unlockPasscode = String(localized: "lock.secret.passcode", defaultValue: "passcode", bundle: .module)
    static let unlockPassword = String(localized: "lock.secret.password", defaultValue: "password", bundle: .module)

    static func requireBiometricOrSecret(biometric: String, secret: String) -> String {
        String(localized: "settings.requireBiometricOrSecret", defaultValue: "Require \(biometric) or \(secret)", bundle: .module)
    }

    static func requireSecret(secret: String) -> String {
        String(localized: "settings.requireSecret", defaultValue: "Require \(secret)", bundle: .module)
    }

    static func unlockWith(method: String) -> String {
        String(localized: "lock.unlockWith", defaultValue: "Unlock with \(method)", bundle: .module)
    }

    static func unlockReasonBiometricOrSecret(biometric: String, secret: String) -> String {
        String(localized: "lock.reasonBiometricOrSecret", defaultValue: "Use \(biometric) or your \(secret) to unlock your conversations.", bundle: .module)
    }

    static func unlockReasonSecret(secret: String) -> String {
        String(localized: "lock.reasonSecret", defaultValue: "Use your \(secret) to unlock your conversations.", bundle: .module)
    }

    static func lockEnableReasonBiometricOrSecret(biometric: String, secret: String) -> String {
        String(localized: "lock.enableReasonBiometricOrSecret", defaultValue: "Confirm it is you with \(biometric) or your \(secret) to turn on the lock.", bundle: .module)
    }

    static func lockEnableReasonSecret(secret: String) -> String {
        String(localized: "lock.enableReasonSecret", defaultValue: "Confirm it is you with your \(secret) to turn on the lock.", bundle: .module)
    }
}
// swiftlint:enable line_length
