import HearthDomain

/// What the lock is called, named for how this device really unlocks: its biometrics, if it has any, and the
/// passcode, which a Mac calls its password.
struct UnlockWording: Hashable {
    let biometry: BiometryKind
    /// Whether the device's own secret is a password, as on a Mac, rather than a passcode.
    let usesPassword: Bool

    /// Whether this build runs on a Mac, where the secret is a password.
    static var isMac: Bool {
        #if targetEnvironment(macCatalyst)
        true
        #else
        false
        #endif
    }

    init(biometry: BiometryKind, usesPassword: Bool = UnlockWording.isMac) {
        self.biometry = biometry
        self.usesPassword = usesPassword
    }

    /// The switch in the settings: "Require Face ID or passcode", "Require password".
    var requireTitle: String {
        guard let biometric else {
            return Strings.requireSecret(secret: secret)
        }
        return Strings.requireBiometricOrSecret(biometric: biometric, secret: secret)
    }

    /// The button on the lock screen: "Unlock with Touch ID", "Unlock with passcode".
    var unlockTitle: String {
        Strings.unlockWith(method: biometric ?? secret)
    }

    /// What the system shows while asking to unlock.
    var unlockReason: String {
        guard let biometric else {
            return Strings.unlockReasonSecret(secret: secret)
        }
        return Strings.unlockReasonBiometricOrSecret(biometric: biometric, secret: secret)
    }

    /// What the system shows while asking to turn the lock on.
    var enableReason: String {
        guard let biometric else {
            return Strings.lockEnableReasonSecret(secret: secret)
        }
        return Strings.lockEnableReasonBiometricOrSecret(biometric: biometric, secret: secret)
    }

    private var secret: String {
        usesPassword ? Strings.unlockPassword : Strings.unlockPasscode
    }

    private var biometric: String? {
        switch biometry {
        case .none:
            nil
        case .faceID:
            Strings.biometryFaceID
        case .touchID:
            Strings.biometryTouchID
        case .opticID:
            Strings.biometryOpticID
        }
    }
}
