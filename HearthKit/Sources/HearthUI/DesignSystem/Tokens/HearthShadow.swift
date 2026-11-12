import SwiftUI

/// A soft shadow that lifts a surface off the paper. Apply one with `hearthShadow(_:)`.
struct HearthShadow {
    let color: Color
    let radius: CGFloat
    let y: CGFloat

    /// Beneath the composer.
    static let composer = HearthShadow(color: .black.opacity(0.05), radius: 10, y: 2)
    /// Beneath a quiet floating button, such as Settings.
    static let floating = HearthShadow(color: .black.opacity(0.06), radius: 8, y: 3)
    /// Beneath the prominent floating button, New chat.
    static let floatingProminent = HearthShadow(color: .black.opacity(0.12), radius: 8, y: 3)
}

extension View {
    /// Casts one of the app's shadows.
    func hearthShadow(_ shadow: HearthShadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: 0, y: shadow.y)
    }
}
