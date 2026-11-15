import Foundation

/// Reads search queries out of a model's answer, however untidily it wrote them.
///
/// The model is asked for JSON, and often gives it wrapped in a code fence, in an object, with a sentence before
/// it, or as a plain list. Each of those is read; anything else yields nothing.
public struct ResearchQueryParser: Sendable {
    /// The names a model gives the list when it wraps it in an object.
    private static let listKeys = ["queries", "search_queries", "searches", "follow_up_queries", "followups"]
    /// The names a model gives the query when each entry is an object.
    private static let queryKeys = ["query", "q", "search", "text"]

    public init() {}

    /// The queries in an answer, without repeats and never more than `limit`.
    ///
    /// - Parameter allowsLines: Whether an answer that holds no JSON may be read as one query a line. That suits a
    ///   plan, where something is always wanted; it does not suit a question that may be answered with "none".
    public func queries(from answer: String, limit: Int, allowsLines: Bool) -> [String] {
        let found = jsonQueries(in: answer) ?? (allowsLines ? lineQueries(in: answer) : [])
        var seen: Set<String> = []
        let distinct = found.map(Self.tidied).filter { query in
            !query.isEmpty && seen.insert(query.lowercased()).inserted
        }
        return Array(distinct.prefix(max(limit, 0)))
    }

    /// The queries for a plan: those in the answer, or the question itself when the answer holds none.
    public func plan(from answer: String, question: String) -> [String] {
        let planned = queries(from: answer, limit: ResearchLimits.maximumQueries, allowsLines: true)
        let fallback = Self.tidied(question)
        return planned.isEmpty && !fallback.isEmpty ? [fallback] : planned
    }

    // MARK: JSON

    /// The queries in the first piece of JSON that holds any; `nil` when the answer holds no JSON that can be read.
    private func jsonQueries(in answer: String) -> [String]? {
        let candidates = [answer, Self.span(of: answer, from: "{", to: "}"), Self.span(of: answer, from: "[", to: "]")]
        for candidate in candidates.compactMap({ $0 }) {
            guard let data = candidate.data(using: .utf8),
                  let value = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else {
                continue
            }
            if let queries = Self.queries(in: value) {
                return queries
            }
        }
        return nil
    }

    /// The queries in a decoded value: a list of them, or an object that holds such a list.
    private static func queries(in value: Any) -> [String]? {
        if let list = value as? [Any] {
            return list.compactMap { entry in
                if let text = entry as? String {
                    return text
                }
                let object = entry as? [String: Any]
                return queryKeys.lazy.compactMap { object?[$0] as? String }.first
            }
        }
        guard let object = value as? [String: Any] else {
            return nil
        }
        let named = listKeys.lazy.compactMap { object[$0] as? [Any] }.first
        let list = named ?? object.keys.sorted().lazy.compactMap { object[$0] as? [Any] }.first
        return list.flatMap(queries(in:))
    }

    /// The text from the first opening mark to the last closing one, both included.
    private static func span(of text: String, from opening: Character, to closing: Character) -> String? {
        guard let start = text.firstIndex(of: opening), let end = text.lastIndex(of: closing), start < end else {
            return nil
        }
        return String(text[start...end])
    }

    // MARK: Lines

    /// One query a line, for an answer written as a list. Lines that only open or close something are passed over.
    private func lineQueries(in answer: String) -> [String] {
        answer.split(whereSeparator: \.isNewline).compactMap { line in
            let text = line.trimmingCharacters(in: .whitespaces)
            let opensSomething = [":", "[", "{"].contains { text.hasSuffix($0) }
            // A line that begins as JSON is what is left of JSON that could not be read, not a query.
            let isMarkup = ["```", "{", "["].contains { text.hasPrefix($0) }
            guard !opensSomething, !isMarkup, text.contains(where: \.isLetter) else {
                return nil
            }
            return text
        }
    }

    /// A query on one line, without list markers, quotes or trailing commas, and of a searchable length.
    private static func tidied(_ query: String) -> String {
        let line = query.split(whereSeparator: \.isNewline).joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: #"^([-*•]|\d+[.)])\s*"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'“”‘’`*_, "))
        return String(line.prefix(ResearchLimits.maximumQueryCharacters)).trimmingCharacters(in: .whitespaces)
    }
}
