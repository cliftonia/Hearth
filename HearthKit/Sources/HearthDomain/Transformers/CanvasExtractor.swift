import Foundation

/// Finds the pieces of standalone work in a reply's Markdown: a fenced block that is a web page or a drawing,
/// and any fenced block long enough to be worth opening on its own.
///
/// A reply is untrusted text, and this is run again and again while one streams, so it reads the text once,
/// line by line, and looks for a title only near the top of a piece.
public struct CanvasExtractor: Sendable {
    /// The fewest lines that make a block of code or a document a piece. A page or a drawing is one at any length.
    public static let minimumLineCount = 15
    /// How far above a piece a heading may be and still name it, in lines.
    static let headingReach = 12
    /// How much of a piece is searched for its own title.
    static let titleSearchLength = 4_000
    static let maximumTitleLength = 80

    /// A fenced block as it was written, before it is known whether it is a piece.
    private struct Fence {
        let opening: String
        let language: String?
        var body: [String] = []
        var closing: String?
    }

    /// A line that is a fence: how many backticks it begins with, the language named after them, and whether it
    /// is bare, as a fence that closes a block must be.
    private struct FenceLine {
        let length: Int
        let language: String?
        let isBare: Bool
    }

    public init() {}

    /// The pieces of the reply, in order.
    public func pieces(from markdown: String) -> [CanvasPiece] {
        segments(from: markdown).compactMap { segment in
            switch segment.kind {
            case .text:
                nil
            case .piece(let piece):
                piece
            }
        }
    }

    /// The reply cut into ordinary Markdown and pieces, in order. A fenced block that is not a piece stays in
    /// the Markdown around it, exactly as it was written.
    public func segments(from markdown: String) -> [CanvasSegment] {
        var kinds: [CanvasSegmentKind] = []
        var text: [String] = []
        // The lines since the last fenced block, where a heading that names the next one may be.
        var gap: [String] = []
        var pieceCount = 0
        var lines = markdown.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).map(String.init)[...]

        while let line = lines.popFirst() {
            guard let opening = Self.fence(in: line) else {
                text.append(line)
                gap.append(line)
                continue
            }
            let fence = Self.block(opening: line, length: opening.length, language: opening.language, lines: &lines)
            if let piece = Self.piece(from: fence, index: pieceCount, heading: Self.heading(above: gap)) {
                if text.contains(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
                    kinds.append(.text(text.joined(separator: "\n")))
                }
                kinds.append(.piece(piece))
                pieceCount += 1
                text = []
            } else {
                text.append(fence.opening)
                text.append(contentsOf: fence.body)
                if let closing = fence.closing {
                    text.append(closing)
                }
            }
            gap = []
        }
        if text.contains(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
            kinds.append(.text(text.joined(separator: "\n")))
        }
        return kinds.enumerated().map { CanvasSegment(id: $0.offset, kind: $0.element) }
    }

    // MARK: Fences

    /// The line read as a fence; `nil` for a line that is not one.
    private static func fence(in line: String) -> FenceLine? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let length = trimmed.prefix { $0 == "`" }.count
        guard length >= 3 else {
            return nil
        }
        let info = trimmed.dropFirst(length).trimmingCharacters(in: .whitespaces)
        // Backticks after the fence make the line inline code, such as ```this```, and not a fence.
        guard !info.contains("`") else {
            return nil
        }
        let language = info.split(separator: " ").first.map(String.init)
        return FenceLine(length: length, language: language, isBare: info.isEmpty)
    }

    /// Everything up to the fence that closes the block, or to the end of the text when it has not been closed,
    /// as while a reply streams in.
    ///
    /// A block is closed by a bare fence at least as long as the one that opened it. A Markdown document often
    /// holds fenced blocks of its own behind fences no longer than its own; those are counted in and out, so the
    /// document ends where it was meant to.
    private static func block(opening: String, length: Int, language: String?, lines: inout ArraySlice<String>) -> Fence {
        var block = Fence(opening: opening, language: language)
        let isDocument = isMarkdown(language)
        var depth = 0
        while let line = lines.popFirst() {
            if let inner = fence(in: line) {
                if inner.isBare, depth > 0 {
                    depth -= 1
                } else if inner.isBare, inner.length >= length {
                    block.closing = line
                    break
                } else if isDocument, !inner.isBare {
                    depth += 1
                }
            }
            block.body.append(line)
        }
        return block
    }

    private static func isMarkdown(_ language: String?) -> Bool {
        ["markdown", "md"].contains(language?.lowercased() ?? "")
    }

    // MARK: Pieces

    /// The piece a fenced block makes, or `nil` when it is an ordinary block that stays in the reply.
    private static func piece(from fence: Fence, index: Int, heading: String?) -> CanvasPiece? {
        var body = fence.body[...]
        while let last = body.last, last.trimmingCharacters(in: .whitespaces).isEmpty {
            body.removeLast()
        }
        let text = body.joined(separator: "\n")
        guard let kind = kind(language: fence.language, text: text, lineCount: body.count) else {
            return nil
        }
        // A closed block with nothing in it is not work; one still open may be about to be.
        guard !body.isEmpty || fence.closing == nil else {
            return nil
        }
        return CanvasPiece(
            index: index,
            kind: kind,
            title: title(kind: kind, text: text) ?? heading,
            text: text,
            lineCount: body.count,
            isClosed: fence.closing != nil
        )
    }

    /// A page or a drawing by its language or by how it begins; otherwise a document or code if it is long enough.
    private static func kind(language: String?, text: String, lineCount: Int) -> CanvasKind? {
        let tag = language?.lowercased() ?? ""
        let start = text.prefix(400).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if ["html", "htm", "xhtml"].contains(tag) || start.hasPrefix("<!doctype html") || start.hasPrefix("<html") {
            return .html
        }
        if tag == "svg" || start.hasPrefix("<svg") || (start.hasPrefix("<?xml") && start.contains("<svg")) {
            return .svg
        }
        guard lineCount >= minimumLineCount else {
            return nil
        }
        return isMarkdown(language) ? .markdown : .code(language: language)
    }

    // MARK: Titles

    /// The name a piece gives itself: a page's or a drawing's `<title>`, or a document's first heading.
    private static func title(kind: CanvasKind, text: String) -> String? {
        let top = String(text.prefix(titleSearchLength))
        switch kind {
        case .html, .svg:
            guard let match = top.firstMatch(of: /(?is)<title[^>]*>(.*?)<\/title>/) else {
                return nil
            }
            return tidied(unescaped(String(match.1)))
        case .markdown:
            return top.split(whereSeparator: \.isNewline).lazy.compactMap { headingText(String($0)) }.first
        case .code:
            return nil
        }
    }

    /// The nearest heading above a piece, if one is close enough to be about it.
    private static func heading(above gap: [String]) -> String? {
        gap.suffix(headingReach).reversed().lazy.compactMap { headingText($0) }.first
    }

    /// The words of a Markdown heading, without its marks; `nil` for a line that is not one.
    private static func headingText(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let level = trimmed.prefix { $0 == "#" }.count
        let rest = trimmed.dropFirst(level)
        guard (1...6).contains(level), rest.first?.isWhitespace == true else {
            return nil
        }
        let words = rest.replacingOccurrences(of: "*", with: "").replacingOccurrences(of: "`", with: "")
        return tidied(words.trimmingCharacters(in: CharacterSet(charactersIn: "#: ").union(.whitespaces)))
    }

    /// A title on one line and of a sensible length; `nil` when nothing is left of it.
    private static func tidied(_ title: String) -> String? {
        let words = title.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return words.isEmpty ? nil : String(words.prefix(maximumTitleLength))
    }

    /// The few character references a title is likely to hold, as the characters they stand for.
    private static func unescaped(_ text: String) -> String {
        [("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&#39;", "'"), ("&amp;", "&")].reduce(text) {
            $0.replacingOccurrences(of: $1.0, with: $1.1)
        }
    }
}
