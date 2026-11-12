import HearthDomain
import SwiftUI

// How the theme setting is named and applied; the domain only knows its three cases.
extension AppearanceKind {
    /// The colour scheme to force, or `nil` to follow the device.
    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            nil
        case .light:
            .light
        case .dark:
            .dark
        }
    }

    /// The name shown in the theme picker.
    var title: String {
        switch self {
        case .system:
            Strings.themeSystem
        case .light:
            Strings.themeLight
        case .dark:
            Strings.themeDark
        }
    }
}
