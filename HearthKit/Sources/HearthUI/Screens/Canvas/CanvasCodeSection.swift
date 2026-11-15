import SwiftUI
import UIKit

/// A piece as it was written: monospaced, never wrapped, scrolling both ways, with its lines numbered.
struct CanvasCodeSection: View {
    let code: String
    /// Whether the code is still arriving, in which case its end is kept in view.
    let isWriting: Bool

    /// Read so that the numbers' column is measured again when the text size changes.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let gutter = Self.gutter(for: code)
        ScrollView(.vertical) {
            HStack(alignment: .top, spacing: 0) {
                // The numbers stand in a column of their own, so they stay put while the code scrolls sideways.
                // The column is exactly as wide as the longest number; anything before a number is cut off.
                Text(verbatim: gutter.text)
                    .font(HearthFont.code)
                    .foregroundStyle(HearthColor.mute)
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: true, vertical: true)
                    .frame(width: Self.width(ofDigits: gutter.digitCount), alignment: .trailing)
                    .clipped()
                    .padding(.leading, HearthSpacing.s12)
                    .padding(.vertical, HearthSpacing.s12)
                    .accessibilityHidden(true)
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(verbatim: code)
                        .font(HearthFont.code)
                        .foregroundStyle(HearthColor.ink)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: true, vertical: true)
                        .padding(HearthSpacing.s12)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .defaultScrollAnchor(isWriting ? .bottom : .top)
        .background(HearthColor.card)
    }

    /// The column of line numbers for the code, and how many digits its longest number has.
    ///
    /// Each number is padded to the same width. A line of code is taller than the rest when it holds a character
    /// the monospaced face lacks, such as an emoji, so such characters are repeated in front of that line's
    /// number, where the view cuts them off: the two lines are then the same height and the numbers stay in step.
    static func gutter(for code: String) -> (text: String, digitCount: Int) {
        let lines = code.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        let digitCount = String(lines.count).count
        let numbered = lines.enumerated().map { offset, line in
            let number = String(offset + 1)
            let padding = String(repeating: " ", count: digitCount - number.count)
            return String(line.filter { !isPlain($0) }) + padding + number
        }
        return (numbered.joined(separator: "\n"), digitCount)
    }

    /// Whether the monospaced face draws the character itself: Latin letters, digits and common punctuation.
    private static func isPlain(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy { $0.value < 0x0250 || (0x2010...0x2027).contains($0.value) }
    }

    /// The width of a number of that many digits in the face code is set in.
    private static func width(ofDigits count: Int) -> CGFloat {
        let size = UIFont.preferredFont(forTextStyle: .footnote).pointSize
        let digit = ("0" as NSString).size(withAttributes: [.font: UIFont.monospacedSystemFont(ofSize: size, weight: .regular)])
        return (digit.width * CGFloat(count)).rounded(.up)
    }
}
