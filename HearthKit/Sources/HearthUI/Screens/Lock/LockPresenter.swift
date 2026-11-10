import HearthDomain
import Observation
import SwiftUI

@MainActor
protocol LockPresenterDelegate: AnyObject {
    func lockPresenterDidLock(_ presenter: LockPresenter)
    func lockPresenterDidUnlock(_ presenter: LockPresenter)
}

@MainActor
@Observable
final class LockViewModel {
    /// The conversations are hidden until the owner unlocks.
    var isLocked: Bool
    /// The conversations are hidden while the app is not in front, so the app switcher shows nothing.
    var isObscured = false
    var isAuthenticating = false

    init(isLocked: Bool) {
        self.isLocked = isLocked
    }
}

/// Keeps the app behind Face ID, Touch ID or the passcode when the lock is turned on in Settings.
@MainActor
final class LockPresenter {
    let viewModel: LockViewModel
    weak var delegate: (any LockPresenterDelegate)?

    private let authentication: AuthenticationProvider
    private let isEnabled: @MainActor () -> Bool
    /// The unlock prompt is offered once each time the app comes forward; after a refusal the owner asks for it.
    private var promptsWhenActive = true

    init(authentication: AuthenticationProvider, isEnabled: @escaping @MainActor () -> Bool) {
        self.authentication = authentication
        self.isEnabled = isEnabled
        self.viewModel = LockViewModel(isLocked: isEnabled())
    }

    func sceneAction(_ phase: ScenePhase) async {
        guard isEnabled() else {
            viewModel.isLocked = false
            viewModel.isObscured = false
            return
        }
        switch phase {
        case .background:
            lock()
        case .inactive:
            viewModel.isObscured = true
        case .active:
            viewModel.isObscured = false
            if viewModel.isLocked, promptsWhenActive {
                await unlockAction()
            }
        @unknown default:
            lock()
        }
    }

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
