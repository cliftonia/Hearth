import SwiftUI
import UIKit

/// Shows the lock screen in a window of its own, above every sheet, alert, picker and camera the app can present.
///
/// An overlay inside the app's own view sits beneath anything presented over it, so it cannot hide a sheet
/// from the app switcher or from someone holding a locked phone.
@MainActor
final class LockWindowController {
    private var window: UIWindow?

    /// Raises the lock window, or removes it. The colour scheme is the chosen theme, which a new window would not inherit.
    func setCovered(_ isCovered: Bool, presenter: LockPresenter, colorScheme: ColorScheme?) {
        guard isCovered else {
            window?.isHidden = true
            window = nil
            return
        }
        if window == nil {
            guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else {
                return
            }
            // Put the keyboard away, so that nothing half-typed stays on show beneath it.
            Keyboard.dismiss()
            let window = UIWindow(windowScene: scene)
            window.windowLevel = .alert + 1
            window.rootViewController = UIHostingController(rootView: LockView(presenter: presenter))
            window.isHidden = false
            self.window = window
        }
        window?.overrideUserInterfaceStyle = Self.interfaceStyle(for: colorScheme)
    }

    private static func interfaceStyle(for colorScheme: ColorScheme?) -> UIUserInterfaceStyle {
        switch colorScheme {
        case .light:
            .light
        case .dark:
            .dark
        case nil:
            .unspecified
        @unknown default:
            .unspecified
        }
    }
}
