import LocalAuthentication

/// Asks the phone's owner to prove who they are, by Face ID, Touch ID or passcode.
public struct AuthenticationService: Sendable {
    public init() {}

    /// Whether the owner passed. A cancelled or failed attempt, or a phone with no passcode, is simply a no.
    public func authenticate(reason: String) async -> Bool {
        (try? await LAContext().evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)) ?? false
    }
}
