import SwiftUI
import UIKit

/// The chosen theme, set on the app's windows themselves.
///
/// A theme given to a view with `preferredColorScheme` reaches a sheet only if the sheet is given it too, and a sheet
/// that was given dark keeps it when the choice goes back to following the system. Set on each window instead, the
/// theme reaches the root, every sheet and cover presented in it, and the lock window, and following the system again
/// really does follow it.
enum InterfaceStyle {
    /// The window style for a theme: light, dark, or the system's own for no choice.
    static func style(for colorScheme: ColorScheme?) -> UIUserInterfaceStyle {
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

    /// Gives every window of the app the theme.
    @MainActor
    static func apply(_ colorScheme: ColorScheme?) {
        let style = style(for: colorScheme)
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else {
                continue
            }
            for window in windowScene.windows {
                window.overrideUserInterfaceStyle = style
            }
        }
    }
}
