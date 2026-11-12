import HearthDomain
import SwiftUI

/// What the lock tells the coordinator, so the rest of the app can fall silent or carry on.
@MainActor
protocol LockPresenterDelegate: AnyObject {
    func lockPresenterDidLock(_ presenter: LockPresenter)
    func lockPresenterDidUnlock(_ presenter: LockPresenter)
}

/// Keeps the app behind Face ID, Touch ID or the passcode when the lock is turned on in Settings.
@MainActor
final class LockPresenter {
    let viewModel: LockViewModel
    weak var delegate: (any LockPresenterDelegate)?

    private let authentication: AuthenticationProvider
    /// Whether the lock is turned on in Settings, asked afresh each time since it can change.
    private let isEnabled: @MainActor () -> Bool
    /// The unlock prompt is offered once each time the app comes forward; after a refusal the owner asks for it.
    private var promptsWhenActive = true

    init(authentication: AuthenticationProvider, isEnabled: @escaping @MainActor () -> Bool) {
        self.authentication = authentication
        self.isEnabled = isEnabled
        self.viewModel = LockViewModel(isLocked: isEnabled())
    }

    /// Follows the app coming forward or leaving, then asks the owner to unlock if that is now due.
    func sceneAction(_ phase: ScenePhase) async {
        if sceneChanged(to: phase) {
            await unlockAction()
        }
    }

    /// Hides or locks at once, before the system pictures the app for its switcher.
    /// Returns whether the owner should now be asked to unlock.
    func sceneChanged(to phase: ScenePhase) -> Bool {
        guard isEnabled() else {
            viewModel.isLocked = false
            viewModel.isObscured = false
            return false
        }
        switch phase {
        case .background:
            lock()
            return false
        case .inactive:
            viewModel.isObscured = true
            return false
        case .active:
            viewModel.isObscured = false
            return viewModel.isLocked && promptsWhenActive
        @unknown default:
            lock()
            return false
        }
    }

    /// Asks for Face ID, Touch ID or the passcode, and opens the app for its owner.
    func unlockAction() async {
        guard viewModel.isLocked, !viewModel.isAuthenticating else {
            return
        }
        promptsWhenActive = false
        viewModel.isAuthenticating = true
        let isOwner = await authentication.authenticate(Strings.unlockReason)
        viewModel.isAuthenticating = false
        if isOwner {
            viewModel.isLocked = false
            delegate?.lockPresenterDidUnlock(self)
        }
    }

    private func lock() {
        promptsWhenActive = true
        guard !viewModel.isLocked else {
            return
        }
        viewModel.isLocked = true
        delegate?.lockPresenterDidLock(self)
    }
}
