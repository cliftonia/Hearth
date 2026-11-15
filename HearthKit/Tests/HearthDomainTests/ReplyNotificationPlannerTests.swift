import Foundation
@testable import HearthDomain
import Testing

/// When a finished reply is announced, and what the announcement may say.
struct ReplyNotificationPlannerTests {
    private let planner = ReplyNotificationPlanner()
    private let reply = Message(role: .assistant, text: "The **capital** of France\nis Paris.")
    private let chat = Conversation(title: "France")

    @Test func `a reply that finishes off screen is announced with its opening words under the chat's title`() {
        let notice = planner.notice(for: reply, in: chat, isEnabled: true, isOnScreen: false)

        #expect(notice == .text(title: "France", excerpt: "The **capital** of France is Paris."))
    }

    @Test(arguments: [(true, true), (false, false), (false, true)])
    func `nothing is announced while the app is on screen or the switch is off`(isEnabled: Bool, isOnScreen: Bool) {
        #expect(planner.notice(for: reply, in: chat, isEnabled: isEnabled, isOnScreen: isOnScreen) == nil)
    }

    @Test func `a private chat gives away neither its title nor its words`() {
        let privateChat = Conversation(title: "A secret", isPrivate: true)
        let picture = Message(role: .assistant, text: "Made in 4 s", imagesJPEG: [Data([1])])

        #expect(planner.notice(for: reply, in: privateChat, isEnabled: true, isOnScreen: false) == .discreet)
        #expect(planner.notice(for: picture, in: privateChat, isEnabled: true, isOnScreen: false) == .discreet)
    }

    @Test func `a picture is announced as a picture, not by its caption`() {
        let picture = Message(role: .assistant, text: "Made in 4 s", imagesJPEG: [Data([1])])

        #expect(planner.notice(for: picture, in: chat, isEnabled: true, isOnScreen: false) == .picture(title: "France"))
    }

    @Test func `a reply that came to nothing, or a message of the user's, is not announced`() {
        let empty = Message(role: .assistant, text: "  \n ")
        let asked = Message(role: .user, text: "What is the capital of France?")

        #expect(planner.notice(for: empty, in: chat, isEnabled: true, isOnScreen: false) == nil)
        #expect(planner.notice(for: asked, in: chat, isEnabled: true, isOnScreen: false) == nil)
    }

    @Test func `a long reply is cut at a word and marked as cut`() {
        let long = String(repeating: "word ", count: 80)

        let excerpt = ReplyNotificationPlanner.excerpt(of: long)

        #expect(excerpt.count <= ReplyNotificationPlanner.maximumExcerptLength + 1)
        #expect(excerpt.hasSuffix("word…"))
    }
}
