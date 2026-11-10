import Foundation
import HearthDomain

/// Collects a streamed reply and hands whole sentences on to be spoken.
@MainActor
final class SpokenReplyFeed {
    private static let captionLength = 220

    private var chunker = SentenceChunker()
    private var text = ""
    private let continuation: AsyncStream<String>.Continuation

    init(continuation: AsyncStream<String>.Continuation) {
        self.continuation = continuation
    }

    /// The end of the reply so far, short enough to read at a glance.
    var caption: String {
        let spoken = SentenceChunker.speakable(text)
        return spoken.count > Self.captionLength ? "…" + spoken.suffix(Self.captionLength) : spoken
    }

    /// Returns whether the new text completed a sentence.
    @discardableResult
    func append(_ delta: String) -> Bool {
        text += delta
        let sentences = chunker.append(delta)
        sentences.forEach { continuation.yield($0) }
        return !sentences.isEmpty
    }

    func finish() {
        chunker.finish().forEach { continuation.yield($0) }
        continuation.finish()
    }
}
