import Foundation

/// Reduces a web page to the text a reader would see, for handing to a model.
///
/// The page is untrusted, so the markup is read as bytes in one forward pass. Every search either
/// moves the pass forward or is made once and remembered, so no page can make it take longer than
/// a small multiple of its own length.
public struct HTMLTextTransformer: Sendable {
    /// Markup beyond this is ignored, so that a huge page cannot stall the phone.
    private static let maximumInputLength = 300_000
    /// Elements whose contents are not part of what the page says.
    private static let hiddenElements: Set<String> = ["script", "style", "noscript", "svg", "nav", "header", "footer", "form", "aside", "iframe", "template"]
    /// Tags that end a line of text.
    private static let lineBreakingTags: Set<String> = ["br", "/p", "/div", "/li", "/h1", "/h2", "/h3", "/h4", "/h5", "/h6", "/tr", "/section", "/article"]

    public init() {}

    /// The readable text of the page, a line for each block of it, cut to the given length.
    public func text(from html: String, maximumLength: Int) -> String {
        let bytes = mainContent(of: Array(html.utf8.prefix(Self.maximumInputLength)))
        let text = decodingEntities(in: String(decoding: strippingMarkup(from: bytes), as: UTF8.self))
        let lines = text.split(whereSeparator: \.isNewline)
            .map { $0.split(whereSeparator: \.isWhitespace).joined(separator: " ") }
            .filter { !$0.isEmpty }
        return String(lines.joined(separator: "\n").prefix(maximumLength))
    }

    // MARK: Markup

    /// The page's article or main region when it marks one, otherwise all of it.
    private func mainContent(of bytes: [UInt8]) -> [UInt8] {
        for tag in ["article", "main"] {
            guard let open = firstIndex(of: Array("<\(tag)".utf8), in: bytes, from: 0),
                  let close = lastIndex(of: Array("</\(tag)".utf8), in: bytes),
                  close - open > 500 else {
                continue
            }
            return Array(bytes[open..<close])
        }
        return bytes
    }

    /// Drops comments, tags and the contents of scripts, styles, navigation and the like.
    private func strippingMarkup(from bytes: [UInt8]) -> [UInt8] {
        var result: [UInt8] = []
        result.reserveCapacity(bytes.count)
        // A search that finds nothing ahead is made once: nothing later can succeed where it failed.
        var unclosedElements: Set<String> = []
        var hasClosingBracketAhead = true
        var index = 0
        while index < bytes.count {
            guard bytes[index] == UInt8(ascii: "<") else {
                result.append(bytes[index])
                index += 1
                continue
            }
            if matches(Array("<!--".utf8), in: bytes, at: index) {
                guard let end = firstIndex(of: Array("-->".utf8), in: bytes, from: index + 4) else {
                    return result
                }
                index = end + 3
                continue
            }
            let name = tagName(in: bytes, after: index)
            if Self.hiddenElements.contains(name), !unclosedElements.contains(name) {
                if let closing = firstIndex(of: Array("</\(name)".utf8), in: bytes, from: index + 1) {
                    index = (bytes[closing...].firstIndex(of: UInt8(ascii: ">")) ?? bytes.count - 1) + 1
                    result.append(UInt8(ascii: " "))
                    continue
                }
                unclosedElements.insert(name)
            }
            if hasClosingBracketAhead, let end = bytes[index...].firstIndex(of: UInt8(ascii: ">")) {
                result.append(Self.lineBreakingTags.contains(name) ? UInt8(ascii: "\n") : UInt8(ascii: " "))
                index = end + 1
            } else {
                // No tag can close from here on, so the bracket is text.
                hasClosingBracketAhead = false
                result.append(bytes[index])
                index += 1
            }
        }
        return result
    }

    /// The lower-cased name of the tag opening at the index, with its leading slash if it is a closing tag.
    private func tagName(in bytes: [UInt8], after index: Int) -> String {
        var name: [UInt8] = []
        var cursor = index + 1
        while cursor < bytes.count, name.count < 12 {
            let byte = bytes[cursor] | 0x20
            let isLetterOrDigit = (UInt8(ascii: "a")...UInt8(ascii: "z")).contains(byte) || (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(bytes[cursor])
            if isLetterOrDigit {
                name.append((UInt8(ascii: "0")...UInt8(ascii: "9")).contains(bytes[cursor]) ? bytes[cursor] : byte)
            } else if bytes[cursor] == UInt8(ascii: "/"), name.isEmpty {
                name.append(bytes[cursor])
            } else {
                break
            }
            cursor += 1
        }
        return String(decoding: name, as: UTF8.self)
    }

    // MARK: Byte search

    /// Whether the lower-case ASCII needle sits at the index, whatever the case of the text.
    private func matches(_ needle: [UInt8], in bytes: [UInt8], at index: Int) -> Bool {
        guard index + needle.count <= bytes.count else {
            return false
        }
        for offset in needle.indices {
            let byte = bytes[index + offset]
            let folded = (UInt8(ascii: "A")...UInt8(ascii: "Z")).contains(byte) ? byte | 0x20 : byte
            if folded != needle[offset] {
                return false
            }
        }
        return true
    }

    /// The first place at or after `start` where the needle sits, whatever the case of the text.
    private func firstIndex(of needle: [UInt8], in bytes: [UInt8], from start: Int) -> Int? {
        guard bytes.count >= needle.count, start <= bytes.count - needle.count else {
            return nil
        }
        return (start...(bytes.count - needle.count)).first { matches(needle, in: bytes, at: $0) }
    }

    /// The last place where the needle sits, whatever the case of the text.
    private func lastIndex(of needle: [UInt8], in bytes: [UInt8]) -> Int? {
        guard bytes.count >= needle.count else {
            return nil
        }
        return (0...(bytes.count - needle.count)).last { matches(needle, in: bytes, at: $0) }
    }

    // MARK: Entities

    /// Turns the common named entities, and numbered ones such as `&#8217;`, back into the characters they stand for.
    private func decodingEntities(in text: String) -> String {
        var result = text
        let named = ["&nbsp;": " ", "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&apos;": "'", "&#39;": "'",
                     "&mdash;": "—", "&ndash;": "–", "&hellip;": "…", "&rsquo;": "’", "&lsquo;": "‘", "&rdquo;": "”", "&ldquo;": "“"]
        for (entity, character) in named {
            result = result.replacingOccurrences(of: entity, with: character)
        }
        guard let regex = try? NSRegularExpression(pattern: #"&#(\d{2,6});"#) else {
            return result
        }
        let source = result as NSString
        var decoded = ""
        var position = 0
        for match in regex.matches(in: result, range: NSRange(location: 0, length: source.length)) {
            decoded += source.substring(with: NSRange(location: position, length: match.range.location - position))
            let digits = source.substring(with: match.range(at: 1))
            decoded += UInt32(digits).flatMap(Unicode.Scalar.init).map { String(Character($0)) } ?? source.substring(with: match.range)
            position = match.range.location + match.range.length
        }
        return decoded + source.substring(from: position)
    }
}
