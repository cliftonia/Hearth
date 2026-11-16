import Foundation

/// Keeps the parts of a reply apart when the model stops in the middle of it.
///
/// A model may write a few words, stop to search the web or change its memory, and then carry on in a fresh
/// request. The fresh request knows nothing of where the last one stopped, so its first words would run straight on
/// from the last ones ("Let me look.## Results"), and a heading or a list it begins with would not be read as one.
/// The joiner puts a paragraph break between the two parts, as many newlines as are missing and no more.
struct ReplyJoiner: Sendable {
    /// How many newlines the reply so far ends with, up to the two that make a paragraph break.
    private var trailingNewlines = 0
    private var hasWritten = false
    /// Whether the model has stopped since it last wrote, so that its next words begin a new part.
    private var isNewPart = false

    /// Notes that the model is being asked again, after stopping to act.
    mutating func modelResumes() {
        isNewPart = hasWritten
    }

    /// The text to report for this piece of the reply: the piece itself, after a break if it begins a new part.
    mutating func join(_ text: String) -> String {
        guard !text.isEmpty else {
            return text
        }
        var joined = text
        if isNewPart {
            isNewPart = false
            let leadingNewlines = text.prefix { $0 == "\n" }.count
            let missing = max(0, 2 - trailingNewlines - leadingNewlines)
            joined = String(repeating: "\n", count: missing) + text
        }
        hasWritten = true
        let ending = joined.reversed().prefix { $0 == "\n" }.count
        trailingNewlines = ending == joined.count ? min(2, trailingNewlines + ending) : min(2, ending)
        return joined
    }
}
