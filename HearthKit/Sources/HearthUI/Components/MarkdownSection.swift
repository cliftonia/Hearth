import HearthDomain
import SwiftUI
import UIKit

/// A reply laid out from Markdown: headings, paragraphs, lists, quotes and code.
struct MarkdownSection: View {
    private static let quoteBarWidth: CGFloat = 3
    static let paragraphLineSpacing: CGFloat = 3

    let markdown: String

    var body: some View {
        VStack(alignment: .leading, spacing: HearthSpacing.s12) {
            ForEach(MarkdownTransformer().blocks(from: markdown)) { block in
                view(for: block.kind)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // A reply is untrusted text: only links to web pages are opened when tapped.
        .environment(\.openURL, OpenURLAction { url in
            SearchSource.isWebLink(url) ? .systemAction : .discarded
        })
    }

    /// The view for one block of the reply.
    @ViewBuilder
    private func view(for kind: MarkdownBlockKind) -> some View {
        switch kind {
        case .heading(let level, let text):
            Text(Self.inline(text))
                .font(HearthFont.heading(level: level))
                .foregroundStyle(HearthColor.ink)
                .accessibilityAddTraits(.isHeader)
        case .paragraph(let text):
            Text(Self.inline(text))
                .font(.body)
                .foregroundStyle(HearthColor.ink)
                .lineSpacing(Self.paragraphLineSpacing)
        case .code(let language, let text):
            CodeBlockSection(language: language, code: text)
        case .list(let isOrdered, let items):
            ListSection(isOrdered: isOrdered, items: items)
        case .quote(let text):
            Text(Self.inline(text))
                .font(.body)
                .foregroundStyle(HearthColor.mute)
                .padding(.leading, HearthSpacing.s12)
                .overlay(alignment: .leading) {
                    Rectangle().fill(HearthColor.line).frame(width: Self.quoteBarWidth)
                }
        case .table(let header, let rows):
            TableSection(header: header, rows: rows)
        case .math(let latex):
            ScrollView(.horizontal, showsIndicators: false) {
                Text(MathTransformer().readable(latex))
                    .font(HearthFont.math)
                    .foregroundStyle(HearthColor.ink)
                    .padding(.vertical, HearthSpacing.s4)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        case .rule:
            Hairline()
        }
    }

    /// Bold, italic, inline code and links; text that does not parse is shown as written.
    static func inline(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        let readable = MathTransformer().readableInline(text)
        return (try? AttributedString(markdown: readable, options: options)) ?? AttributedString(readable)
    }
}

/// A table that scrolls sideways when it is wider than the chat.
private struct TableSection: View {
    /// A cell and its column, so that `ForEach` can tell equal texts apart.
    private struct Cell: Identifiable {
        let id: Int
        let text: String
    }

    /// A row of cells and its position in the table.
    private struct Row: Identifiable {
        let id: Int
        let cells: [Cell]
    }

    let header: [String]
    let rows: [[String]]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Grid(alignment: .leading, horizontalSpacing: HearthSpacing.s18, verticalSpacing: HearthSpacing.s8) {
                GridRow {
                    ForEach(Self.cells(header)) { cell in
                        Text(MarkdownSection.inline(cell.text))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(HearthColor.ink)
                    }
                }
                ForEach(rows.enumerated().map { Row(id: $0.offset, cells: Self.cells($0.element)) }) { row in
                    Hairline()
                        .gridCellUnsizedAxes(.horizontal)
                    GridRow {
                        ForEach(row.cells) { cell in
                            Text(MarkdownSection.inline(cell.text))
                                .font(.subheadline)
                                .foregroundStyle(HearthColor.ink)
                        }
                    }
                }
            }
            .padding(HearthSpacing.s12)
        }
        .cardSurface()
    }

    private static func cells(_ texts: [String]) -> [Cell] {
        texts.enumerated().map { Cell(id: $0.offset, text: $0.element) }
    }
}

/// A bulleted or numbered list.
private struct ListSection: View {
    /// An item and its position, which is also its number in an ordered list.
    private struct Item: Identifiable {
        let id: Int
        let text: String
    }

    let isOrdered: Bool
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: HearthSpacing.s6) {
            ForEach(items.enumerated().map { Item(id: $0.offset, text: $0.element) }) { item in
                HStack(alignment: .firstTextBaseline, spacing: HearthSpacing.s8) {
                    Text(isOrdered ? "\(item.id + 1)." : "•")
                        .font(.body.monospacedDigit())
                        .foregroundStyle(HearthColor.mute)
                        .accessibilityHidden(!isOrdered)
                    Text(MarkdownSection.inline(item.text))
                        .font(.body)
                        .foregroundStyle(HearthColor.ink)
                        .lineSpacing(MarkdownSection.paragraphLineSpacing)
                }
            }
        }
    }
}

/// A block of code under a bar naming its language, with a button that copies it.
private struct CodeBlockSection: View {
    private static let copyButtonSize = CGSize(width: 32, height: 28)

    let language: String?
    let code: String

    @State private var copyCount = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: HearthSpacing.s8) {
                Text(language ?? Strings.code)
                    .font(.caption)
                    .foregroundStyle(HearthColor.mute)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(action: copyAction) {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                        .foregroundStyle(HearthColor.mute)
                        .frame(size: Self.copyButtonSize)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Strings.copyCode)
            }
            .padding(.leading, HearthSpacing.s12)
            .padding(.trailing, HearthSpacing.s4)
            Hairline()
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(HearthFont.code)
                    .foregroundStyle(HearthColor.ink)
                    .textSelection(.enabled)
                    .padding(HearthSpacing.s12)
            }
        }
        .cardSurface()
        .sensoryFeedback(.success, trigger: copyCount)
    }

    private func copyAction() {
        UIPasteboard.general.string = code
        copyCount += 1
    }
}
