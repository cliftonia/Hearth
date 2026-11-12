import Observation

/// Whether the conversations are hidden, and why.
@MainActor
@Observable
final class LockViewModel {
    /// The conversations are hidden until the owner unlocks.
    var isLocked: Bool
    /// The conversations are hidden while the app is not in front, so the app switcher shows nothing.
    var isObscured = false
    /// The system's unlock prompt is on screen, so another must not be raised.
    var isAuthenticating = false

    init(isLocked: Bool) {
        self.isLocked = isLocked
    }
}
