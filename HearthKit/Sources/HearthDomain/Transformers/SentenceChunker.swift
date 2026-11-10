import Foundation

/// Cuts text that arrives a few characters at a time into whole sentences, ready to be spoken.
public struct SentenceChunker: Sendable {
    private static let minimumLength = 24

    private var buffer = ""

    public init() {}

    /// Adds newly arrived text and returns any sentences it completed.
    public mutating func append(_ delta: String) -> [String] {
        buffer += delta
        guard let boundary = lastBoundary(in: buffer) else {
            return []
        }
        let complete = String(buffer[..<boundary])
        guard complete.trimmingCharacters(in: .whitespacesAndNewlines).count >= Self.minimumLength else {
            return []
        }
        buffer = String(buffer[boundary...])
        return Self.sentences(in: complete)
    }

    /// Returns whatever is left once no more text will arrive.
    public mutating func finish() -> [String] {
        let rest = buffer
        buffer = ""
        return Self.sentences(in: rest)
    }

    /// Text with the markup a voice should not read removed.
    public static func speakable(_ text: String) -> String {
        var result = text
        let replacements: [(pattern: String, template: String)] = [
            ("```[\\s\\S]*?(```|$)", " "),
            ("!?\\[([^\\]]*)\\]\\([^)]*\\)", "$1"),
            ("https?://\\S+", " "),
            ("\\[\\d+\\]", ""),
            ("(?m)^\\s*(#{1,6}|[-*+]|>)\\s+", ""),
            ("[*_`#|]", "")
        ]
        for replacement in replacements {
            result = result.replacingOccurrences(of: replacement.pattern, with: replacement.template, options: .regularExpression)
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The index just past the last sentence ending that is followed by more text.
    private func lastBoundary(in text: String) -> String.Index? {
        var boundary: String.Index?
        var index = text.startIndex
        while index < text.endIndex {
            let next = text.index(after: index)
            let character = text[index]
            let endsLine = character.isNewline
            let endsSentence = ".!?".contains(character) && next < text.endIndex && text[next].isWhitespace
            if endsLine || endsSentence {
                boundary = next
            }
            index = next
        }
        return boundary
    }

    private static func sentences(in text: String) -> [String] {
        let spoken = speakable(text)
        return spoken.contains(where: \.isLetter) || spoken.contains(where: \.isNumber) ? [spoken] : []
    }
}
