import Observation

/// Where a voice conversation stands.
enum VoiceStateKind: Hashable {
    case listening
    case thinking
    case speaking
    case muted
    /// Listening cannot begin: permission was refused, or the recogniser failed.
    case unavailable
}

/// What the voice screen shows: the state, the words being heard or spoken, and who is answering.
@MainActor
@Observable
final class VoiceViewModel {
    var state: VoiceStateKind = .listening
    /// What is being heard, the end of the reply being spoken, or the reason nothing can be heard.
    var caption = ""
    var modelName = ""
    var voiceName = ""
}
