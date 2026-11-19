import Foundation
import HearthDomain
import SwiftUI

/// Markdown read into blocks, and its inline styling into attributed text, once each and kept, so that a reply drawn
/// again, as a later word streams in or the list scrolls, is not read through again.
@MainActor
enum ParsedMarkdown {
    /// The most texts kept at once; the system may let go of them sooner when memory is short.
    private static let countLimit = 512
    private static let blockCache = makeCache(of: Blocks.self)
    private static let inlineCache = makeCache(of: Inline.self)
    private static let codeCache = makeCache(of: Inline.self)

    /// The blocks a reply is laid out from.
    static func blocks(from markdown: String) -> [MarkdownBlock] {
        let key = markdown as NSString
        if let kept = blockCache.object(forKey: key) {
            return kept.value
        }
        let blocks = MarkdownTransformer().blocks(from: markdown)
        blockCache.setObject(Blocks(blocks), forKey: key)
        return blocks
    }

    /// Bold, italic, inline code and links; text that does not parse is shown as written.
    static func inline(_ text: String) -> AttributedString {
        let key = text as NSString
        if let kept = inlineCache.object(forKey: key) {
            return kept.value
        }
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        let readable = MathTransformer().readableInline(text)
        let styled = (try? AttributedString(markdown: readable, options: options)) ?? AttributedString(readable)
        inlineCache.setObject(Inline(styled), forKey: key)
        return styled
    }

    /// A block of code with its keywords, strings, comments and numbers each in their colour.
    static func code(_ code: String, language: String?) -> AttributedString {
        // The language is part of the key: the same lines are coloured differently as Python and as Swift.
        let key = "\(language ?? "")\u{0}\(code)" as NSString
        if let kept = codeCache.object(forKey: key) {
            return kept.value
        }
        var styled = AttributedString()
        for token in CodeHighlighter().tokens(in: code, language: language) {
            var run = AttributedString(token.text)
            // Set by the attribute's type: by key path, the compiler warns that the path cannot cross to another task.
            run[AttributeScopes.SwiftUIAttributes.ForegroundColorAttribute.self] = color(for: token.kind)
            styled.append(run)
        }
        codeCache.setObject(Inline(styled), forKey: key)
        return styled
    }

    private static func color(for kind: CodeTokenKind) -> Color {
        switch kind {
        case .plain:
            HearthColor.ink
        case .keyword:
            HearthColor.codeKeyword
        case .string:
            HearthColor.codeString
        case .comment:
            HearthColor.mute
        case .number:
            HearthColor.codeNumber
        }
    }

    private static func makeCache<Value: AnyObject>(of _: Value.Type) -> NSCache<NSString, Value> {
        let cache = NSCache<NSString, Value>()
        cache.countLimit = countLimit
        return cache
    }

    /// A cache keeps objects, so each value is held in one.
    private final class Blocks {
        let value: [MarkdownBlock]

        init(_ value: [MarkdownBlock]) {
            self.value = value
        }
    }

    private final class Inline {
        let value: AttributedString

        init(_ value: AttributedString) {
            self.value = value
        }
    }
}
