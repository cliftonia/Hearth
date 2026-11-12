import SwiftUI
import UIKit

/// The app's palette. Every colour follows the light or dark appearance, and views take their colours from here alone.
enum HearthColor {
    // MARK: Surfaces

    /// The background of every screen.
    static let paper = Color(lightHex: 0xF3F5F1, darkHex: 0x121715)
    /// Raised surfaces: the composer, code blocks, pills and round buttons.
    static let card = Color(lightHex: 0xFFFFFF, darkHex: 0x1B2220)
    /// The user's message bubble, and the selected chat in the list.
    static let bubble = Color(lightHex: 0xE6EBE5, darkHex: 0x232C29)
    /// Borders and dividers.
    static let line = Color(lightHex: 0xDDE2DC, darkHex: 0x2A3330)
    /// The veil drawn over the chat while the drawer is open; its opacity follows the drawer.
    static let scrim = Color.black

    // MARK: Text

    /// Body text and primary symbols.
    static let ink = Color(lightHex: 0x18211E, darkHex: 0xE9EEEA)
    /// Secondary text, placeholders and quiet symbols.
    static let mute = Color(lightHex: 0x6C7772, darkHex: 0x8B9691)

    // MARK: Accent

    /// The brand colour: the tint, primary buttons and anything switched on.
    static let pine = Color(lightHex: 0x2C6B5A, darkHex: 0x6FC2A8)
    /// The fill behind something switched on.
    static let pineSoft = Color(lightHex: 0xDCEAE4, darkHex: 0x1F3A32)
    /// Text and symbols drawn on pine.
    static let onPine = Color(lightHex: 0xFFFFFF, darkHex: 0x0E1211)

    // MARK: Status

    /// Errors, recording, and buttons that end or destroy something.
    static let danger = Color(lightHex: 0xC8553D, darkHex: 0xE0705A)
    /// Symbols drawn on danger.
    static let onDanger = Color.white
    /// The server can be reached.
    static let online = Color(lightHex: 0x3FA66B, darkHex: 0x57C283)

    // MARK: Voice orb

    /// The orb's gradient, from its highlight through its body to its shaded edge.
    static let orb = [
        Color(lightHex: 0x9FE0CB, darkHex: 0x9FE0CB),
        Color(lightHex: 0x2C6B5A, darkHex: 0x3E8A75),
        Color(lightHex: 0x1B4A3D, darkHex: 0x1B4A3D)
    ]
}

extension Color {
    /// A colour that follows the light or dark appearance.
    init(lightHex: UInt32, darkHex: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? darkHex : lightHex)
        })
    }
}

private extension UIColor {
    /// An opaque colour from six hexadecimal digits, as in `0x2C6B5A`.
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
