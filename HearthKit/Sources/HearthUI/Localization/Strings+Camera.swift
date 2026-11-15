import Foundation

// The camera of a voice conversation.
// swiftlint:disable line_length
extension Strings {
    static let cameraTurnOn = String(localized: "camera.turnOn", defaultValue: "Turn camera on", bundle: .module)
    static let cameraTurnOff = String(localized: "camera.turnOff", defaultValue: "Turn camera off", bundle: .module)
    static let cameraHint = String(localized: "camera.hint", defaultValue: "One picture is sent with each thing you say. Nothing is recorded.", bundle: .module)
    static let cameraFlip = String(localized: "camera.flip", defaultValue: "Switch camera", bundle: .module)
    static let cameraPreview = String(localized: "camera.preview", defaultValue: "What the camera sees", bundle: .module)
    static let cameraModelCannotSee = String(localized: "camera.modelCannotSee", defaultValue: "This model cannot see pictures, so the camera stays off. Choose one marked Sees pictures to use it.", bundle: .module)
    static let cameraUnavailable = String(localized: "camera.unavailable", defaultValue: "The camera could not be started. You can carry on talking without it.", bundle: .module)
    #if targetEnvironment(macCatalyst)
    static let cameraDenied = String(localized: "camera.denied.mac", defaultValue: "The camera is turned off for Hearth in System Settings. You can carry on talking without it.", bundle: .module)
    static let cameraOpenSettings = String(localized: "camera.openSettings.mac", defaultValue: "Open System Settings", bundle: .module)
    #else
    static let cameraDenied = String(localized: "camera.denied", defaultValue: "The camera is turned off for Hearth in the Settings app. You can carry on talking without it.", bundle: .module)
    static let cameraOpenSettings = String(localized: "camera.openSettings", defaultValue: "Open the Settings app", bundle: .module)
    #endif
}
// swiftlint:enable line_length
