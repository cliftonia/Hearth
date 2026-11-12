import Foundation
@testable import HearthDomain
import Testing

/// The feed that turns a streamed reply into sentences for the voice.
@MainActor
struct SpokenReplyFeedTests {
    /// A feed and the stream its sentences arrive on.
    private func makeTestSubject() -> (feed: SpokenReplyFeed, sentences: AsyncStream<String>) {
        let (sentences, continuation) = AsyncStream.makeStream(of: String.self)
        return (SpokenReplyFeed(continuation: continuation), sentences)
    }

    @Test func `whole sentences are handed on as they complete, and the rest when the reply ends`() async {
        let (feed, sentences) = makeTestSubject()
        #expect(!feed.append("The kettle has only just"))
        #expect(feed.append(" come to the boil. Now the tea"))
        feed.finish()
        var spoken: [String] = []
        for await sentence in sentences {
            spoken.append(sentence)
        }
        #expect(spoken == ["The kettle has only just come to the boil.", "Now the tea"])
    }

    @Test func `the caption leaves out markup and keeps only the end of a long reply`() {
        let (feed, _) = makeTestSubject()
        feed.append("**Short** reply.")
        #expect(feed.caption == "Short reply.")
        feed.append(String(repeating: " word", count: 100))
        #expect(feed.caption.hasPrefix("…"))
        #expect(feed.caption.count == 221)
    }
}
