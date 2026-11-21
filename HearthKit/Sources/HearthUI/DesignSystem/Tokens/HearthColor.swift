import SwiftUI
import UIKit

/// The app's palette. Every colour follows the light or dark appearance, and views take their colours from here alone.
///
/// The colours that carry meaning in a quiet tone, the secondary text, the lines, pine, danger and the online dot, are
/// drawn stronger when Increase Contrast is on.
enum HearthColor {
    // MARK: Surfaces

    /// The background of every screen.
    static let paper = Color(lightHex: 0xF3F5F1, darkHex: 0x121715)
    /// Raised surfaces: the composer, code blocks, pills and round buttons.
    static let card = Color(lightHex: 0xFFFFFF, darkHex: 0x1B2220)
    /// The user's message bubble, and the selected chat in the list.
    static let bubble = Color(lightHex: 0xE6EBE5, darkHex: 0x232C29)
    /// Borders and dividers.
    static let line = Color(lightHex: 0xDDE2DC, darkHex: 0x2A3330, highContrast: (light: 0x7A847D, dark: 0x6A7570))
    /// The edge of a see-through surface. Lighter than `line` in the dark, where glass catches the light along its
    /// upper and lower edges and a border as dark as `line` would leave its sides unseen.
    static let glassEdge = Color(lightHex: 0xDDE2DC, darkHex: 0x55605B, highContrast: (light: 0x7A847D, dark: 0x8A9590))
    /// The veil drawn over the chat while the drawer is open; its opacity follows the drawer.
    static let scrim = Color.black

    // MARK: Text

    /// Body text and primary symbols.
    static let ink = Color(lightHex: 0x18211E, darkHex: 0xE9EEEA)
    /// Secondary text, placeholders and quiet symbols.
    static let mute = Color(lightHex: 0x5F6A65, darkHex: 0x8B9691, highContrast: (light: 0x46504B, dark: 0xB4BEB9))

    // MARK: Accent

    /// The brand colour: the tint, primary buttons and anything switched on.
    static let pine = Color(lightHex: 0x2C6B5A, darkHex: 0x6FC2A8, highContrast: (light: 0x1E5446, dark: 0x95DCC5))
    /// The fill behind something switched on.
    static let pineSoft = Color(lightHex: 0xDCEAE4, darkHex: 0x1F3A32)
    /// Text and symbols drawn on pine.
    static let onPine = Color(lightHex: 0xFFFFFF, darkHex: 0x0E1211)

    // MARK: Status

    /// Errors, recording, and buttons that end or destroy something, drawn as text or a symbol on a surface.
    static let danger = Color(lightHex: 0xB0472F, darkHex: 0xE0705A, highContrast: (light: 0x8F3520, dark: 0xF29A87))
    /// The fill of a button that ends something, such as a voice conversation. Deeper than `danger` in the dark, so
    /// that `onDanger` reads on it.
    static let dangerFill = Color(lightHex: 0xB0472F, darkHex: 0xB54E3A, highContrast: (light: 0x8F3520, dark: 0x9A3F2D))
    /// Symbols drawn on `dangerFill`.
    static let onDanger = Color.white
    /// The dot that says the server can be reached. Not for text: words of success are drawn in `pine`.
    static let online = Color(lightHex: 0x3FA66B, darkHex: 0x57C283, highContrast: (light: 0x22784A, dark: 0x86E0AA))

    // MARK: Code

    /// The words a language reserves, in a block of code. Each of these reads on `card` in both appearances.
    static let codeKeyword = Color(lightHex: 0x2C6B5A, darkHex: 0x6FC2A8, highContrast: (light: 0x1E5446, dark: 0x95DCC5))
    /// Text in quotes, in a block of code.
    static let codeString = Color(lightHex: 0x8A4B12, darkHex: 0xE0B15A, highContrast: (light: 0x6B3808, dark: 0xF0CB85))
    /// Numbers, in a block of code.
    static let codeNumber = Color(lightHex: 0x3B5BA5, darkHex: 0x8FB0F0, highContrast: (light: 0x2A4585, dark: 0xB4CCFA))

    // MARK: Voice orb

    /// The orb's gradient, from its highlight through its body to its shaded edge.
    static let orb = [
        Color(lightHex: 0x9FE0CB, darkHex: 0x9FE0CB),
        Color(lightHex: 0x2C6B5A, darkHex: 0x3E8A75),
        Color(lightHex: 0x1B4A3D, darkHex: 0x1B4A3D)
    ]
}

extension Color {
    /// A colour that follows the light or dark appearance, and Increase Contrast when given colours for it.
    ///
    /// - Parameter highContrast: The light and dark colours drawn while Increase Contrast is on; without them the
    ///   ordinary ones are drawn then too.
    init(lightHex: UInt32, darkHex: UInt32, highContrast: (light: UInt32, dark: UInt32)? = nil) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: Self.hex(for: traits, lightHex: lightHex, darkHex: darkHex, highContrast: highContrast))
        })
    }

    /// Which of the colours the given traits call for.
    static func hex(for traits: UITraitCollection, lightHex: UInt32, darkHex: UInt32, highContrast: (light: UInt32, dark: UInt32)?) -> UInt32 {
        let isDark = traits.userInterfaceStyle == .dark
        if traits.accessibilityContrast == .high, let highContrast {
            return isDark ? highContrast.dark : highContrast.light
        }
        return isDark ? darkHex : lightHex
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
