import Foundation

/// Which way a camera faces.
public enum CameraPositionKind: Hashable, Sendable {
    /// Away from the user, at what they are looking at.
    case back
    /// Towards the user.
    case front
}

/// What cameras the device has.
public struct CameraAvailability: Hashable, Sendable {
    public let hasCamera: Bool
    /// Whether there is a camera on each side to change between.
    public let canFlip: Bool

    public init(hasCamera: Bool, canFlip: Bool) {
        self.hasCamera = hasCamera
        self.canFlip = canFlip
    }
}

/// How far the camera of a voice conversation has got towards being on.
public enum VoiceCameraPhaseKind: Hashable, Sendable {
    case off
    /// The user is being asked, or has been asked before, whether the camera may be used.
    case asking
    /// Leave is given and the camera is starting.
    case starting
    /// The camera is on, and a picture goes with each spoken turn.
    case on
}

/// Why the camera is not on, when the user would expect it to be.
public enum VoiceCameraNoticeKind: Hashable, Sendable {
    /// The system does not let the app use the camera.
    case permissionRefused
    /// The camera could not be started.
    case unavailable
}

/// What the camera button of a voice conversation can do.
public enum VoiceCameraControlKind: Hashable, Sendable {
    /// There is no camera, so there is no button.
    case hidden
    /// The chosen model cannot see pictures; the button is shown but does nothing.
    case disabled
    case enabled
}

/// The camera of a voice conversation: whether it is on, which way it faces, and why it is off if it should not be.
///
/// It only keeps the account; the presenter works the camera. Turning the camera on takes time, because the user
/// may have to be asked first, and in that time the conversation may be closed, the app may leave the screen or the
/// button may be tapped again. Each attempt to turn it on is numbered, so that one overtaken by any of those can
/// never leave the camera running.
public struct VoiceCamera: Hashable, Sendable {
    public private(set) var phase = VoiceCameraPhaseKind.off
    public private(set) var position = CameraPositionKind.back
    public private(set) var notice: VoiceCameraNoticeKind?
    /// The number of the latest attempt to turn the camera on.
    private var attempt = 0

    public init() {}

    /// Whether a picture is taken with each spoken turn.
    public var attachesFrames: Bool {
        phase == .on
    }

    /// Whether the picture's card is on screen: from the moment leave is given until the camera is turned off.
    public var isPreviewShown: Bool {
        phase == .starting || phase == .on
    }

    /// What the camera button can do on this device with this model.
    public static func control(availability: CameraAvailability, modelCanSee: Bool) -> VoiceCameraControlKind {
        guard availability.hasCamera else {
            return .hidden
        }
        return modelCanSee ? .enabled : .disabled
    }

    /// The button was tapped with the camera off. Returns the number of the attempt, or `nil` when the camera is
    /// already on its way or the model could not see what it shows.
    public mutating func turnOn(modelCanSee: Bool) -> Int? {
        guard phase == .off, modelCanSee else {
            return nil
        }
        attempt += 1
        phase = .asking
        notice = nil
        return attempt
    }

    /// Leave was given. Returns whether the camera should now be started.
    public mutating func allow(_ number: Int) -> Bool {
        guard number == attempt, phase == .asking else {
            return false
        }
        phase = .starting
        return true
    }

    /// The camera has started. Returns whether it is still wanted; if not, it must be stopped again.
    public mutating func begin(_ number: Int) -> Bool {
        guard number == attempt, phase == .starting else {
            return false
        }
        phase = .on
        return true
    }

    /// The attempt came to nothing, for the reason given. An attempt already overtaken changes nothing.
    public mutating func fail(_ number: Int, notice: VoiceCameraNoticeKind) {
        guard number == attempt, phase != .off else {
            return
        }
        phase = .off
        self.notice = notice
    }

    /// The camera is to be off: the button was tapped, or the conversation closed. Returns whether there was
    /// anything to turn off.
    public mutating func turnOff() -> Bool {
        guard phase != .off else {
            return false
        }
        phase = .off
        return true
    }

    /// The app is no longer in front of the user. Returns whether the camera is to be turned off.
    ///
    /// The system's own question about the camera also takes the app from the front, though not off the screen;
    /// the attempt that asked it is left to finish.
    public mutating func leaveForeground(isOffScreen: Bool) -> Bool {
        if phase == .asking, !isOffScreen {
            return false
        }
        return turnOff()
    }

    /// The camera now in use faces the given way. Ignored unless the camera is on.
    public mutating func face(_ position: CameraPositionKind) {
        guard phase == .on else {
            return
        }
        self.position = position
    }
}
