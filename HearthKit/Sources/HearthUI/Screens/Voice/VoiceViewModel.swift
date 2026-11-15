import HearthDomain
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

    // MARK: Camera

    /// Whether the camera is on, which way it faces, and why it is off if it should not be.
    var camera = VoiceCamera()
    /// What cameras the device has. Until the screen opens, none.
    var cameraAvailability = CameraAvailability(hasCamera: false, canFlip: false)
    /// Whether the chosen model accepts pictures.
    var modelCanSee = false

    /// What the camera button can do.
    var cameraControl: VoiceCameraControlKind {
        VoiceCamera.control(availability: cameraAvailability, modelCanSee: modelCanSee)
    }
}
