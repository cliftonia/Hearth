import SwiftUI

/// The typefaces that give the app its character: a serif for the brand, headings and speech, a monospace for code.
///
/// Ordinary interface text uses `Font.hearth(_:)` with a system text style (`.body`, `.subheadline`, `.footnote`).
/// Everything here is built the same way, so all of it grows with Dynamic Type and is set a little larger on a Mac.
enum HearthFont {
    /// The app's name beside its mark.
    static let brand = Font.hearth(.title2, design: .serif).weight(.bold)
    /// The one large line on an otherwise empty screen. A Mac's window has the room for a larger one.
    #if targetEnvironment(macCatalyst)
    static let display = Font.hearth(.largeTitle, design: .serif)
    #else
    static let display = Font.hearth(.title, design: .serif)
    #endif
    /// The name of a chat or a project in the chat list. A Mac sets it a step smaller, as its lists are.
    #if targetEnvironment(macCatalyst)
    static let listRow = Font.hearth(.subheadline)
    #else
    static let listRow = Font.hearth(.body)
    #endif
    /// The caption of a voice conversation.
    static let spoken = Font.hearth(.title3, design: .serif)
    /// The contents of a code block.
    static let code = Font.hearth(.footnote, design: .monospaced)
    /// A formula set on a line of its own.
    static let math = Font.hearth(.title3, design: .serif)
    /// The symbol inside an `IconButton`.
    static let icon = Font.hearth(.body, weight: .medium)

    /// A Markdown heading. Levels beyond the second share one size, so a deep outline stays calm.
    static func heading(level: Int) -> Font {
        switch level {
        case 1:
            Font.hearth(.title2, design: .serif).weight(.semibold)
        case 2:
            Font.hearth(.title3, design: .serif).weight(.semibold)
        default:
            Font.hearth(.headline, design: .serif)
        }
    }
}
