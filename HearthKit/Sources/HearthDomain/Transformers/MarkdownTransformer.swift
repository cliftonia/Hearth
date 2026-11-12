import Foundation

/// The kinds of block a reply is laid out from, each with the text it holds.
public enum MarkdownBlockKind: Hashable, Sendable {
    case heading(level: Int, text: String)
    case paragraph(String)
    case code(language: String?, text: String)
    case list(isOrdered: Bool, items: [String])
    case quote(String)
    case table(header: [String], rows: [[String]])
    case math(String)
    case rule
}

/// One block of a reply, identified by its place in the reply.
public struct MarkdownBlock: Identifiable, Hashable, Sendable {
    public let id: Int
    public let kind: MarkdownBlockKind
}

/// Splits Markdown into the blocks a chat reply is laid out from. Inline styling is left in the text.
public struct MarkdownTransformer: Sendable {
    public init() {}

    /// The blocks of the text, in order. Lines that belong to no other block are gathered into paragraphs.
    public func blocks(from markdown: String) -> [MarkdownBlock] {
        var kinds: [MarkdownBlockKind] = []
        var paragraph: [String] = []
        var lines = markdown.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).map(String.init)[...]

        func flushParagraph() {
            if !paragraph.isEmpty {
                kinds.append(.paragraph(paragraph.joined(separator: "\n")))
                paragraph = []
            }
        }

        while let line = lines.popFirst() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                flushParagraph()
                kinds.append(codeBlock(opening: trimmed, lines: &lines))
            } else if trimmed.isEmpty {
                flushParagraph()
            } else if let block = table(header: trimmed, lines: &lines) ?? math(opening: trimmed, lines: &lines) {
                flushParagraph()
                kinds.append(block)
            } else if let block = singleLineBlock(trimmed) {
                flushParagraph()
                kinds.append(block)
            } else if let item = listItem(trimmed) {
                flushParagraph()
                kinds.append(list(first: item, lines: &lines))
            } else {
                paragraph.append(trimmed)
            }
        }
        flushParagraph()
        return kinds.enumerated().map { MarkdownBlock(id: $0.offset, kind: $0.element) }
    }

    // MARK: Code

    /// Everything up to the closing fence, or to the end when the fence has not been closed, as while a reply streams in.
    private func codeBlock(opening: String, lines: inout ArraySlice<String>) -> MarkdownBlockKind {
        let language = opening.dropFirst(3).trimmingCharacters(in: .whitespaces)
        var code: [String] = []
        while let line = lines.popFirst() {
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                break
            }
            code.append(line)
        }
        return .code(language: language.isEmpty ? nil : language, text: code.joined(separator: "\n"))
    }

    // MARK: Tables

    /// A table is a row of cells followed by a row of dashes; without the dashes the line is ordinary text.
    private func table(header: String, lines: inout ArraySlice<String>) -> MarkdownBlockKind? {
        guard header.hasPrefix("|"), let separator = lines.first, isTableSeparator(separator) else {
            return nil
        }
        lines.removeFirst()
        var rows: [[String]] = []
        while let next = lines.first?.trimmingCharacters(in: .whitespaces), next.hasPrefix("|") {
            rows.append(cells(in: next))
            lines.removeFirst()
        }
        return .table(header: cells(in: header), rows: rows)
    }

    /// Whether the line is the row of dashes that sits under a table's header.
    private func isTableSeparator(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.contains("-") && trimmed.contains("|") && trimmed.allSatisfy { "|-: ".contains($0) }
    }

    /// The cells of a table row, without the bars at either edge.
    private func cells(in row: String) -> [String] {
        var inner = row.trimmingCharacters(in: .whitespaces)[...]
        if inner.hasPrefix("|") {
            inner = inner.dropFirst()
        }
        if inner.hasSuffix("|") {
            inner = inner.dropLast()
        }
        return inner.split(separator: "|", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
    }

    // MARK: Maths

    /// Display maths, opened by `$$` or `\\[` and closed on the same line or a later one.
    private func math(opening: String, lines: inout ArraySlice<String>) -> MarkdownBlockKind? {
        guard let closing = ["$$": "$$", "\\[": "\\]"].first(where: { opening.hasPrefix($0.key) })?.value else {
            return nil
        }
        var body = [String(opening.dropFirst(2))]
        while !(body.last ?? "").hasSuffix(closing), let next = lines.popFirst() {
            body.append(next.trimmingCharacters(in: .whitespaces))
        }
        if var last = body.popLast() {
            if last.hasSuffix(closing) {
                last.removeLast(closing.count)
            }
            body.append(last)
        }
        return .math(body.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.joined(separator: " "))
    }

    // MARK: Single lines

    /// A heading, rule or quote, each of which takes one line.
    private func singleLineBlock(_ line: String) -> MarkdownBlockKind? {
        // The quantifier braces inside these regex literals are mistaken for code blocks by the linter.
        // swiftlint:disable opening_brace
        if let heading = line.firstMatch(of: /^(#{1,6})\s+(.+)$/) {
            return .heading(level: heading.1.count, text: String(heading.2))
        }
        if line.wholeMatch(of: /^(-{3,}|\*{3,}|_{3,})$/) != nil {
            return .rule
        }
        // swiftlint:enable opening_brace
        if let quote = line.firstMatch(of: /^>\s?(.*)$/) {
            return .quote(String(quote.1))
        }
        return nil
    }

    // MARK: Lists

    /// The text of a bulleted or numbered item, and which of the two it is.
    private func listItem(_ line: String) -> (isOrdered: Bool, text: String)? {
        if let bullet = line.firstMatch(of: /^[-*+]\s+(.+)$/) {
            return (false, String(bullet.1))
        }
        if let numbered = line.firstMatch(of: /^\d+[.)]\s+(.+)$/) {
            return (true, String(numbered.1))
        }
        return nil
    }

    /// Gathers the items that follow the first, for as long as they are of the same sort.
    private func list(first: (isOrdered: Bool, text: String), lines: inout ArraySlice<String>) -> MarkdownBlockKind {
        var items = [first.text]
        while let next = lines.first {
            let trimmed = next.trimmingCharacters(in: .whitespaces)
            if let item = listItem(trimmed), item.isOrdered == first.isOrdered {
                items.append(item.text)
            } else if !trimmed.isEmpty, next.hasPrefix("  "), let last = items.popLast() {
                // An indented line continues the item above it.
                items.append(last + " " + trimmed)
            } else {
                break
            }
            lines.removeFirst()
        }
        return .list(isOrdered: first.isOrdered, items: items)
    }
}
