import Foundation
import HearthData
import LocalAuthentication

/// The biometrics a device unlocks with, if any. Without them the passcode, or a Mac's password, is all there is.
public enum BiometryKind: Sendable, Hashable, CaseIterable {
    case none
    case faceID
    case touchID
    case opticID
}

/// How the domain asks the phone's owner to prove who they are.
public struct AuthenticationProvider: Sendable {
    /// Shows the given reason and returns whether the phone's owner proved who they are.
    public let authenticate: @Sendable (String) async -> Bool
    /// The biometrics the device has, so that what is asked for can be named.
    public let biometry: @Sendable () -> BiometryKind

    public init(
        authenticate: @escaping @Sendable (String) async -> Bool,
        biometry: @escaping @Sendable () -> BiometryKind = { .none }
    ) {
        self.authenticate = authenticate
        self.biometry = biometry
    }
}

public extension AuthenticationProvider {
    /// Backed by Face ID, Touch ID or the passcode.
    static func live(service: AuthenticationService = AuthenticationService()) -> AuthenticationProvider {
        AuthenticationProvider(
            authenticate: { reason in await service.authenticate(reason: reason) },
            biometry: { BiometryKind(service.biometryType()) }
        )
    }
}

extension BiometryKind {
    init(_ type: LABiometryType) {
        switch type {
        case .faceID:
            self = .faceID
        case .touchID:
            self = .touchID
        case .opticID:
            self = .opticID
        case .none:
            self = .none
        @unknown default:
            self = .none
        }
    }
}
