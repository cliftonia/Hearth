import Foundation

/// Reduces a web page to the text a reader would see, for handing to a model.
public struct HTMLTextTransformer: Sendable {
    /// Markup beyond this is ignored, so that a huge page cannot stall the phone.
    private static let maximumInputLength = 600_000

    public init() {}

    public func text(from html: String, maximumLength: Int) -> String {
        var text = String(html.prefix(Self.maximumInputLength))
        text = mainContent(of: text)
        let replacements: [(pattern: String, template: String)] = [
            (#"(?is)<!--.*?-->"#, " "),
            (#"(?is)<(script|style|noscript|svg|nav|header|footer|form|aside|iframe|template)\b.*?</\1\s*>"#, " "),
            (#"(?i)<(br|/p|/div|/li|/h[1-6]|/tr|/section|/article)\b[^>]*>"#, "\n"),
            (#"(?s)<[^>]+>"#, " ")
        ]
        for replacement in replacements {
            text = text.replacingOccurrences(of: replacement.pattern, with: replacement.template, options: .regularExpression)
        }
        text = decodingEntities(in: text)
        let lines = text.split(whereSeparator: \.isNewline)
            .map { $0.split(whereSeparator: \.isWhitespace).joined(separator: " ") }
            .filter { !$0.isEmpty }
        return String(lines.joined(separator: "\n").prefix(maximumLength))
    }

    /// The page's article or main region when it marks one, otherwise all of it.
    private func mainContent(of html: String) -> String {
        for tag in ["article", "main"] {
            let pattern = "(?is)<\(tag)\\b[^>]*>(.*)</\(tag)\\s*>"
            if let range = html.range(of: pattern, options: .regularExpression), html[range].count > 500 {
                return String(html[range])
            }
        }
        return html
    }

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
        for match in regex.matches(in: result, range: NSRange(result.startIndex..., in: result)).reversed() {
            guard let whole = Range(match.range, in: result), let digits = Range(match.range(at: 1), in: result),
                  let code = UInt32(result[digits]), let scalar = Unicode.Scalar(code) else {
                continue
            }
            result.replaceSubrange(whole, with: String(Character(scalar)))
        }
        return result
    }
}
