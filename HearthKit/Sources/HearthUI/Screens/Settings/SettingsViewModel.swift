import HearthDomain
import Observation

/// How a test of the server connection stands.
enum ConnectionCheckKind: Hashable {
    case idle
    case checking
    case succeeded(modelCount: Int)
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
    var voice = ServerSettings.defaultVoice
    var appearance: AppearanceKind = .system
    var customInstructions = ""
    var isAutoReadEnabled = false
    var isLockEnabled = false
    var isFollowUpsEnabled = true
    var isPageReadingEnabled = true
    var isMemoryEnabled = true

    // MARK: Form state

    /// The voices the speech server offers. Empty until it answers, in which case the voice is typed by name.
    var voices: [String] = []
    var voicePreview: VoicePreviewKind = .idle
    /// A memory being written by hand, not yet added.
    var newMemoryText = ""
    var isConfirmingClearMemories = false
    var connectionCheck: ConnectionCheckKind = .idle
}
