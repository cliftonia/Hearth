@testable import HearthDomain
import Testing

/// The title a chat is given as its first message is sent, before the model names it.
struct ProvisionalTitleTests {
    @Test func `a short message is the title as it stands`() {
        #expect(Conversation.provisionalTitle(from: "What time is high tide?") == "What time is high tide?")
        #expect(Conversation.provisionalTitle(from: "").isEmpty)
    }

    @Test func `a long message is cut to its opening characters`() {
        let text = String(repeating: "a", count: Conversation.provisionalTitleLength) + "bcd"

        #expect(Conversation.provisionalTitle(from: text) == String(repeating: "a", count: 48))
    }

    @Test func `a character made of several parts is never split`() {
        let text = String(repeating: "e\u{301}", count: 60)

        #expect(Conversation.provisionalTitle(from: text) == String(repeating: "e\u{301}", count: 48))
    }
}
