import LocalAuthentication

/// Asks the phone's owner to prove who they are, by Face ID, Touch ID or passcode.
public struct AuthenticationService: Sendable {
    public init() {}

    /// Whether the owner passed. A cancelled or failed attempt, or a phone with no passcode, is simply a no.
    public func authenticate(reason: String) async -> Bool {
        (try? await LAContext().evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)) ?? false
    }

    /// The kind of biometrics the device has. The system only fills this in once it has been asked whether
    /// biometrics can be used, whatever that answer is.
    public func biometryType() -> LABiometryType {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.biometryType
    }
}
