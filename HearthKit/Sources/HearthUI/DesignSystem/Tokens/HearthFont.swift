import SwiftUI

/// The typefaces that give the app its character: a serif for the brand, headings and speech, a monospace for code.
///
/// Ordinary interface text uses the system text styles directly (`.body`, `.subheadline`, `.footnote`, `.caption`).
/// Everything here is built on a text style too, so all of it grows with Dynamic Type.
enum HearthFont {
    /// The app's name beside its mark.
    static let brand = Font.system(.title2, design: .serif).weight(.bold)
    /// The one large line on an otherwise empty screen.
    static let display = Font.system(.title, design: .serif).weight(.semibold)
    /// The caption of a voice conversation.
    static let spoken = Font.system(.title3, design: .serif)
    /// The contents of a code block.
    static let code = Font.system(.footnote, design: .monospaced)
    /// A formula set on a line of its own.
    static let math = Font.system(.title3, design: .serif)
    /// The symbol inside an `IconButton`.
    static let icon = Font.system(.body, weight: .medium)

    /// A Markdown heading. Levels beyond the second share one size, so a deep outline stays calm.
    static func heading(level: Int) -> Font {
        switch level {
        case 1:
            Font.system(.title2, design: .serif).weight(.semibold)
        case 2:
            Font.system(.title3, design: .serif).weight(.semibold)
        default:
            Font.system(.headline, design: .serif)
        }
    }
}
