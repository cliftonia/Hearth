import HearthDomain
import SwiftUI
import UIKit

/// A reply laid out from Markdown: headings, paragraphs, lists, quotes and code.
struct MarkdownSection: View {
    let markdown: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(MarkdownTransformer().blocks(from: markdown)) { block in
                view(for: block.kind)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

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
                .lineSpacing(3)
        case .code(let language, let text):
            CodeBlockSection(language: language, code: text)
        case .list(let isOrdered, let items):
            ListSection(isOrdered: isOrdered, items: items)
        case .quote(let text):
            Text(Self.inline(text))
                .font(.body)
                .foregroundStyle(HearthColor.mute)
                .padding(.leading, 12)
                .overlay(alignment: .leading) {
                    Rectangle().fill(HearthColor.line).frame(width: 3)
                }
        case .rule:
            Rectangle().fill(HearthColor.line).frame(height: 1)
        }
    }

    /// Bold, italic, inline code and links; text that does not parse is shown as written.
    static func inline(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}

private struct ListSection: View {
    private struct Item: Identifiable {
        let id: Int
        let text: String
    }

    let isOrdered: Bool
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(items.enumerated().map { Item(id: $0.offset, text: $0.element) }) { item in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(isOrdered ? "\(item.id + 1)." : "•")
                        .font(.body.monospacedDigit())
                        .foregroundStyle(HearthColor.mute)
                        .accessibilityHidden(!isOrdered)
                    Text(MarkdownSection.inline(item.text))
                        .font(.body)
                        .foregroundStyle(HearthColor.ink)
                        .lineSpacing(3)
                }
            }
        }
    }
}

private struct CodeBlockSection: View {
    let language: String?
    let code: String

    @State private var copyCount = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(language ?? Strings.code)
                    .font(.caption)
                    .foregroundStyle(HearthColor.mute)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(action: copyAction) {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                        .foregroundStyle(HearthColor.mute)
                        .frame(width: 32, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Strings.copyCode)
            }
            .padding(.leading, 12)
            .padding(.trailing, 4)
            Rectangle().fill(HearthColor.line).frame(height: 1)
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(HearthFont.code)
                    .foregroundStyle(HearthColor.ink)
                    .textSelection(.enabled)
                    .padding(12)
            }
        }
        .background(HearthColor.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(HearthColor.line, lineWidth: 1)
        }
        .sensoryFeedback(.success, trigger: copyCount)
    }

    private func copyAction() {
        UIPasteboard.general.string = code
        copyCount += 1
    }
}
