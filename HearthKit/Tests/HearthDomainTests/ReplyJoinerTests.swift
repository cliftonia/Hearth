import Foundation
@testable import HearthDomain
import Testing

/// A reply written in parts, around a search or a memory change, reads as separate paragraphs.
struct ReplyJoinerTests {
    @Test func `words written after a search begin a new paragraph`() async throws {
        let fixture = InteractorHarness.makeTestSubject(
            rounds: [[.text("Let me look this up."), .searchRequested(SearchRequest(query: "swift"))], [.text("## Swift 6"), .text(" changed")]],
            search: { _ in [InteractorHarness.source] }
        )

        let events = try await InteractorHarness.events(fixture.subject.run(InteractorHarness.turn(searchMode: .automatic)))

        let text = events.compactMap { event -> String? in
            guard case .text(let text) = event else {
                return nil
            }
            return text
        }.joined()
        #expect(text == "Let me look this up.\n\n## Swift 6 changed")
    }

    @Test(arguments: [
        ("Before.\n", "After", "Before.\n\nAfter"),
        ("Before.\n\n", "After", "Before.\n\nAfter"),
        ("Before.", "\nAfter", "Before.\n\nAfter"),
        ("Before.", "\n\nAfter", "Before.\n\nAfter")
    ])
    func `only the newlines that are missing are added`(before: String, after: String, expected: String) {
        var joiner = ReplyJoiner()
        let first = joiner.join(before)
        joiner.modelResumes()

        #expect(first + joiner.join(after) == expected)
    }

    @Test func `a reply in one part is left as it was written`() {
        var joiner = ReplyJoiner()
        joiner.modelResumes()

        let joined = ["Hel", "lo", "\n", "there"].map { joiner.join($0) }

        #expect(joined == ["Hel", "lo", "\n", "there"])
    }

    @Test func `a model that wrote nothing before it stopped gets no break`() {
        var joiner = ReplyJoiner()
        joiner.modelResumes()
        _ = joiner.join("")
        joiner.modelResumes()

        #expect(joiner.join("Answer") == "Answer")
    }

    @Test func `newlines that end a reply in small pieces are counted together`() {
        var joiner = ReplyJoiner()
        _ = joiner.join("Before.")
        _ = joiner.join("\n")
        _ = joiner.join("\n")
        joiner.modelResumes()

        #expect(joiner.join("After") == "After")
    }
}
