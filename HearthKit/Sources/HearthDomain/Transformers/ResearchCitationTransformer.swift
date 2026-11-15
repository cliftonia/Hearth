import Foundation

/// Makes a report's citations and its list of sources agree.
///
/// A model cites as it pleases: `[1, 2]`, `[3-5]`, `【4†source】`, numbers nothing stands behind, and now and then a
/// list of references of its own at the end. Afterwards every citation is a plain `[n]`, every `n` is a source in
/// the list, and the list holds only what the report cites, numbered from one in the order it was read.
public struct ResearchCitationTransformer: Sendable {
    /// The widest run of numbers one citation may stand for, so that `[1-900]` cannot become nine hundred citations.
    private static let maximumRangeLength = 20
    /// The headings a model puts over a list of references of its own.
    private static let referenceHeadings: Set<String> = ["sources", "references", "citations", "bibliography", "works cited", "source list"]

    public init() {}

    /// - Parameters:
    ///   - text: The report as the model wrote it, citing sources by their place in `sources`, counting from one.
    ///   - sources: The pages the model was given notes on, in the order of their numbers.
    public func tidy(_ text: String, sources: [SearchSource]) -> ResearchReport {
        let body = Self.droppingReferenceList(from: text)
        var cited: Set<Int> = []
        // First pass: learn which sources are cited at all, so that the rest can be dropped and the numbers closed up.
        _ = Self.rewritingCitations(in: body) { numbers in
            cited.formUnion(numbers.filter { $0 >= 1 && $0 <= sources.count })
            return numbers
        }
        guard !cited.isEmpty else {
            // Nothing was cited: the report still rests on every page noted, and no number is left pointing nowhere.
            let bare = Self.rewritingCitations(in: body) { _ in [] }
            return ResearchReport(text: Self.trimmed(bare), sources: sources)
        }
        let kept = cited.sorted()
        let renumbered = Dictionary(uniqueKeysWithValues: kept.enumerated().map { ($0.element, $0.offset + 1) })
        let rewritten = Self.rewritingCitations(in: body) { numbers in
            numbers.compactMap { renumbered[$0] }
        }
        return ResearchReport(text: Self.trimmed(rewritten), sources: kept.map { sources[$0 - 1] })
    }

    // MARK: Citations

    /// Rewrites every citation outside code. `transform` is given a citation's numbers and returns those to
    /// write in their place; when it returns none, the citation is removed together with the space before it.
    private static func rewritingCitations(in text: String, transform: ([Int]) -> [Int]) -> String {
        var isFenced = false
        return text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> String in
                if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    isFenced.toggle()
                    return String(line)
                }
                guard !isFenced else {
                    return String(line)
                }
                // Every second piece between backticks is code, and is left as it is.
                return line.split(separator: "`", omittingEmptySubsequences: false).enumerated()
                    .map { index, piece in
                        index.isMultiple(of: 2) ? rewritingCitations(inProse: String(piece), transform: transform) : String(piece)
                    }
                    .joined(separator: "`")
            }
            .joined(separator: "\n")
    }

    private static func rewritingCitations(inProse prose: String, transform: ([Int]) -> [Int]) -> String {
        // Square brackets holding only numbers, and not the text of a link; or the lenticular brackets some models use.
        let citation = /[ \t]*(?:\[\^?(\d[\d\s,;–-]*)\](?![(:])|【(\d+)[^】]*】)/
        return prose.replacing(citation) { match in
            let numbers = transform(numbers(in: String(match.output.1 ?? match.output.2 ?? "")))
            guard !numbers.isEmpty else {
                return ""
            }
            let leading = match.output.0.prefix { $0 == " " || $0 == "\t" }
            return leading + numbers.map { "[\($0)]" }.joined()
        }
    }

    /// The numbers one citation stands for: `1, 2` is two, `3-5` is three. No number is given twice.
    private static func numbers(in list: String) -> [Int] {
        var numbers: [Int] = []
        for part in list.split(whereSeparator: { $0 == "," || $0 == ";" }) {
            let ends = part.split(whereSeparator: { $0 == "-" || $0 == "–" })
                .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            if ends.count == 2, ends[0] < ends[1], ends[1] - ends[0] < maximumRangeLength {
                numbers += Array(ends[0]...ends[1])
            } else {
                numbers += ends
            }
        }
        var seen: Set<Int> = []
        return numbers.filter { seen.insert($0).inserted }
    }

    // MARK: The model's own list of references

    /// The report without a closing section of references, which the app shows for itself. Only the last heading
    /// of the report is looked at, so a section in the middle that happens to be called "Sources" is kept.
    private static func droppingReferenceList(from text: String) -> String {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        guard let last = lines.lastIndex(where: { isHeading($0) }), last > 0, isReferenceHeading(lines[last]) else {
            return text
        }
        return lines[..<last].joined(separator: "\n")
    }

    private static func isHeading(_ line: Substring) -> Bool {
        let text = line.trimmingCharacters(in: .whitespaces)
        return text.hasPrefix("#") || (text.hasPrefix("**") && text.hasSuffix("**") && text.count > 4)
    }

    private static func isReferenceHeading(_ line: Substring) -> Bool {
        let name = line.trimmingCharacters(in: CharacterSet(charactersIn: "#*: \t")).lowercased()
        return referenceHeadings.contains(name)
    }

    private static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
