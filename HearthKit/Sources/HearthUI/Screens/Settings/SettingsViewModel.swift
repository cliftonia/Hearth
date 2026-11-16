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

/// The settings form: a draft of each setting, bound to its field, and the state of the form's own controls.
@MainActor
@Observable
final class SettingsViewModel {
    // MARK: Draft

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
    var isLockEnabled = false
    var isFollowUpsEnabled = true
    var isPageReadingEnabled = true
    var isMemoryEnabled = true

    // MARK: Applied at once

    /// Whether haptics are played. Like the theme, it takes effect as it is switched, without waiting for Done.
    var isHapticsEnabled = true
    /// Whether a reply that finishes off screen is announced. Takes effect as it is switched.
    var isReplyNotificationsEnabled = false
    /// Whether the answer to a scheduled task that arrives off screen is announced. Takes effect as it is switched.
    var isTaskNotificationsEnabled = false

    // MARK: Form state

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
    /// What went wrong on the profile page, if something did: a photo that could not be kept, or an erasure that failed.
    var profileError: String?

    // MARK: Sync, applied at once

    /// The hub's address as typed; kept when typing ends, when the page closes, and before anything uses it.
    var syncAddress = ""
    /// A new access token being typed. It is never filled from the Keychain, and is emptied once saved.
    var syncTokenDraft = ""
    var isSyncEnabled = false
    var syncCheck: SyncCheckKind = .idle

    /// The names as they stand in the form.
    var profile: UserProfile { UserProfile(fullName: fullName, nickname: nickname) }
}
