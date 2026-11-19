import Foundation

/// Finds the passages of long texts that bear on a question, so that files too long to give a model whole are
/// given as the parts worth reading rather than as their first pages.
///
/// Each text is cut into passages of a few paragraphs, and every passage is scored by the words it shares with the
/// question: a word counts for more the rarer it is among the passages, and a passage that says it often for more
/// than one that says it once, with long passages given no advantage for their length (the scoring known as BM25).
/// It matches words, not meanings, so a question must use some of the words the text does; in return it needs no
/// model, no server and nothing stored, and gives the same answer on every device.
public struct PassageFinder: Sendable {
    /// Stands where text was left out of an excerpt.
    public static let gap = "[…]"

    /// Words too common to tell one passage from another.
    static let commonWords: Set<String> = [
        "a", "about", "an", "and", "are", "as", "at", "be", "but", "by", "can", "do", "does", "for", "from", "had", "has", "have",
        "how", "i", "if", "in", "is", "it", "its", "me", "my", "no", "not", "of", "on", "or", "our", "so", "than", "that", "the",
        "their", "them", "then", "there", "these", "they", "this", "to", "was", "we", "were", "what", "when", "where", "which",
        "who", "why", "will", "with", "would", "you", "your"
    ]

    /// How much a word said again and again in a passage goes on adding to its score.
    private static let saturation = 1.2
    /// How far a passage's score is evened out for its length.
    private static let lengthWeight = 0.75

    /// The most characters in a passage.
    let passageLength: Int

    public init(passageLength: Int = 1200) {
        self.passageLength = passageLength
    }

    /// One excerpt for each text, in the same order: its passages that best match the question, as many as the
    /// allowance holds, in the order they stand in the text, with `gap` wherever something was left out. A text
    /// none of whose passages was chosen has an empty excerpt.
    ///
    /// `nil` when there is nothing to choose by: the texts fit the allowance whole, the question has no words to
    /// search for, or none of its words is in any text.
    public func excerpts(of texts: [String], for question: String, allowance: Int) -> [String]? {
        guard texts.reduce(0, { $0 + $1.count }) > allowance else {
            return nil
        }
        let wanted = Set(terms(in: question))
        let passages = texts.map(passages(of:))
        let chosen = choose(from: passages, wanted: wanted, allowance: allowance)
        guard !chosen.isEmpty else {
            return nil
        }
        return passages.enumerated().map { text, parts in
            excerpt(of: parts, keeping: chosen.filter { $0.text == text }.map(\.passage).sorted())
        }
    }

    // MARK: Cutting

    /// The text cut into passages, which joined give the text back. A passage ends at the end of a line wherever
    /// it can; only a line longer than a passage is cut through.
    func passages(of text: String) -> [String] {
        var passages: [String] = []
        var current = ""
        var length = 0
        // Each line but the first carries the line break before it, so that nothing of the text is lost.
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).enumerated().map { $0.offset == 0 ? String($0.element) : "\n" + $0.element }
        for line in lines {
            var rest = Substring(line)
            while !rest.isEmpty {
                let room = passageLength - length
                if rest.count <= room {
                    current += rest
                    length += rest.count
                    rest = ""
                } else if length > 0 {
                    passages.append(current)
                    (current, length) = ("", 0)
                } else {
                    passages.append(String(rest.prefix(passageLength)))
                    rest = rest.dropFirst(passageLength)
                }
            }
        }
        if length > 0 {
            passages.append(current)
        }
        return passages
    }

    /// The words of a text to search by: in lower case, without the commonest words, and without a plural's
    /// ending, so that `beds` finds `bed`.
    func terms(in text: String) -> [String] {
        text.lowercased()
            .split { !($0.isLetter || $0.isNumber) }
            .map(String.init)
            .filter { $0.count > 1 && !Self.commonWords.contains($0) }
            .map { $0.count > 3 && $0.hasSuffix("s") && !$0.hasSuffix("ss") ? String($0.dropLast()) : $0 }
    }

    // MARK: Choosing

    private struct Place: Hashable {
        let text: Int
        let passage: Int
    }

    /// What one passage holds: how many words in all, and how often each word of the question.
    private struct Count {
        let place: Place
        let length: Int
        let found: [String: Int]
    }

    /// The best-matching passages that fit the allowance together, best first. A passage too long for the room
    /// left is passed over for a shorter one that fits.
    private func choose(from passages: [[String]], wanted: Set<String>, allowance: Int) -> [Place] {
        let scored = scores(of: passages, wanted: wanted)
            .filter { $0.score > 0 }
            // Equal scores are settled by place, so that every device chooses alike.
            .sorted { ($1.score, $0.place.text, $0.place.passage) < ($0.score, $1.place.text, $1.place.passage) }
        var chosen: [Place] = []
        var room = allowance
        for candidate in scored {
            let length = passages[candidate.place.text][candidate.place.passage].count
            if length <= room {
                chosen.append(candidate.place)
                room -= length
            }
        }
        return chosen
    }

    private func scores(of passages: [[String]], wanted: Set<String>) -> [(place: Place, score: Double)] {
        var counts: [Count] = []
        var holders: [String: Int] = [:]
        for (text, parts) in passages.enumerated() {
            for (index, part) in parts.enumerated() {
                let words = terms(in: part)
                let found = Dictionary(words.filter(wanted.contains).map { ($0, 1) }, uniquingKeysWith: +)
                found.keys.forEach { holders[$0, default: 0] += 1 }
                counts.append(Count(place: Place(text: text, passage: index), length: words.count, found: found))
            }
        }
        let total = Double(counts.count)
        let averageLength = max(Double(counts.reduce(0) { $0 + $1.length }) / max(total, 1), 1)
        return counts.map { entry in
            // Summed in the order of the words, so that the sum is the same wherever it is worked out.
            let score = entry.found.keys.sorted().reduce(0.0) { sum, word in
                let said = Double(entry.found[word] ?? 0)
                let held = Double(holders[word] ?? 0)
                let rarity = log(1 + (total - held + 0.5) / (held + 0.5))
                let evened = said + Self.saturation * (1 - Self.lengthWeight + Self.lengthWeight * Double(entry.length) / averageLength)
                return sum + rarity * said * (Self.saturation + 1) / evened
            }
            return (entry.place, score)
        }
    }

    // MARK: Putting together

    /// The kept passages of one text in order: neighbours run on as they did in the text, and `gap` stands on a
    /// line of its own wherever passages between, before or after them were left out.
    private func excerpt(of passages: [String], keeping kept: [Int]) -> String {
        guard let first = kept.first, let last = kept.last else {
            return ""
        }
        var runs: [String] = []
        var run = ""
        for (position, index) in kept.enumerated() {
            if position > 0, index != kept[position - 1] + 1 {
                runs.append(run)
                run = ""
            }
            run += passages[index]
        }
        runs.append(run)
        let body = runs.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.joined(separator: "\n\(Self.gap)\n")
        return (first > 0 ? "\(Self.gap)\n" : "") + body + (last < passages.count - 1 ? "\n\(Self.gap)" : "")
    }
}
