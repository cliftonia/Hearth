import HearthDomain
import Observation

/// How a test of the server connection stands.
enum ConnectionCheckKind: Hashable {
    case idle
    case checking
    case succeeded(modelCount: Int)
    case failed(message: String)
}

/// How a check of the hub on the sync page stands.
enum SyncCheckKind: Hashable {
    case idle
    case checking
    case succeeded
    case failed(message: String)
}

/// Whether a sample of the chosen voice is being spoken, or could not be.
enum VoicePreviewKind: Hashable {
    case idle
    case playing
    case failed
}

/// The settings: each setting as it stands on screen, bound to its control, and the state of the controls themselves.
///
/// Every change is kept as it is made. A switch or a choice is kept at once; typed text is kept when its field is
/// left, when its page closes and when the settings close, so that nothing is written for each letter.
@MainActor
@Observable
final class SettingsViewModel {
    // MARK: Settings

    var ollamaAddress = ""
    var searchAddress = ""
    var speechAddress = ""
    var imageAddress = ""
    /// The model new pictures are made with; `nil` leaves the choice to the app.
    var imageModel: ImageModelKind?
    var fullName = ""
    var nickname = ""
    var voice = ServerSettings.defaultVoice
    var appearance: AppearanceKind = .system
    var customInstructions = ""
    var isAutoReadEnabled = false
    /// The lock's switch. Turning it on is only kept once the owner has shown they can open it.
    var isLockEnabled = false
    var isFollowUpsEnabled = true
    var isPageReadingEnabled = true
    var isMemoryEnabled = true
    var isHapticsEnabled = true
    /// Whether a reply that finishes off screen is announced.
    var isReplyNotificationsEnabled = false
    /// Whether the answer to a scheduled task that arrives off screen is announced.
    var isTaskNotificationsEnabled = false

    // MARK: Navigation

    /// The pages pushed on from the main list, the last on top. A row opens its page by adding to this, never with
    /// a `NavigationLink`; see `SettingsPageKind`.
    var path: [SettingsPageKind] = []

    // MARK: Controls

    /// The voices the speech server offers. Empty until it answers, in which case the voice is typed by name.
    var voices: [String] = []
    var voicePreview: VoicePreviewKind = .idle
    /// What the picture server can do. Empty until it answers.
    var imageCapabilities = ImageCapabilities()
    /// A memory being written by hand, not yet added.
    var newMemoryText = ""
    var isConfirmingClearMemories = false
    var connectionCheck: ConnectionCheckKind = .idle
    /// Whether the system lets the app post notifications, as last asked.
    var notificationPermission: NotificationPermissionKind = .notDetermined
    var isConfirmingErase = false
    /// A photo that could not be kept, said on the profile page.
    var profileError: String?
    /// An erasure that failed part of the way, said beneath the Erase button.
    var eraseError: String?
    /// How the lock's switch names the way this device unlocks.
    var unlockWording = UnlockWording(biometry: .none)

    // MARK: Sync, applied at once

    /// The hub's address as typed; kept when typing ends, when the page closes, and before anything uses it.
    var syncAddress = ""
    /// A new access key being typed. It is never filled from the Keychain, and is emptied once saved.
    var syncTokenDraft = ""
    var isSyncEnabled = false
    var syncCheck: SyncCheckKind = .idle

    /// The names as they stand on screen.
    var profile: UserProfile { UserProfile(fullName: fullName, nickname: nickname) }
}
