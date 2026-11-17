import SwiftUI
import UIKit

/// Shows the lock screen in a window of its own, above every sheet, alert, picker and camera the app can present.
///
/// An overlay inside the app's own view sits beneath anything presented over it, so it cannot hide a sheet
/// from the app switcher or from someone holding a locked phone.
@MainActor
final class LockWindowController {
    /// One lock window for each of the app's windows: the chat's, and on a Mac the settings' as well.
    private var windows: [UIWindow] = []

    /// Raises the lock windows, or removes them. The colour scheme is the chosen theme, which a new window would not
    /// inherit.
    func setCovered(_ isCovered: Bool, presenter: LockPresenter, colorScheme: ColorScheme?) {
        guard isCovered else {
            windows.forEach { $0.isHidden = true }
            windows = []
            return
        }
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let covered = Set(windows.compactMap { $0.windowScene.map(ObjectIdentifier.init) })
        let uncovered = scenes.filter { !covered.contains(ObjectIdentifier($0)) }
        if !uncovered.isEmpty {
            // Put the keyboard away, so that nothing half-typed stays on show beneath it.
            Keyboard.dismiss()
        }
        for scene in uncovered {
            let window = UIWindow(windowScene: scene)
            window.windowLevel = .alert + 1
            window.rootViewController = UIHostingController(rootView: LockView(presenter: presenter))
            window.isHidden = false
            windows.append(window)
        }
        let style = InterfaceStyle.style(for: colorScheme)
        windows.forEach { $0.overrideUserInterfaceStyle = style }
    }
}
