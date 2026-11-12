import Foundation

/// Collects a streamed reply and hands whole sentences on to be spoken.
///
/// The reply's text is poured in as it arrives; each sentence it completes is yielded to the stream the
/// speech interactor reads from, so a reply can be heard while it is still being written.
@MainActor
public final class SpokenReplyFeed {
    private static let captionLength = 220

    private var chunker = SentenceChunker()
    private var text = ""
    private let continuation: AsyncStream<String>.Continuation

    /// - Parameter continuation: Where completed sentences are sent. It is finished by `finish()`.
    public init(continuation: AsyncStream<String>.Continuation) {
        self.continuation = continuation
    }

    /// The end of the reply so far, short enough to read at a glance.
    public var caption: String {
        let spoken = SentenceChunker.speakable(text)
        return spoken.count > Self.captionLength ? "…" + spoken.suffix(Self.captionLength) : spoken
    }

    /// Returns whether the new text completed a sentence.
    @discardableResult
    public func append(_ delta: String) -> Bool {
        text += delta
        let sentences = chunker.append(delta)
        sentences.forEach { continuation.yield($0) }
        return !sentences.isEmpty
    }

    /// Hands on whatever is left and closes the stream, once no more of the reply will arrive.
    public func finish() {
        chunker.finish().forEach { continuation.yield($0) }
        continuation.finish()
    }
}
