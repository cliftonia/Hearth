import Foundation
import HearthDomain
@testable import HearthUI
import Testing

/// How the sidebar's conversations are grouped by age and narrowed by a search.
struct ConversationGrouperTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }

    /// A conversation last active the given number of days before `now`.
    private func conversation(_ title: String, daysAgo: Int, isPinned: Bool = false) -> Conversation {
        Conversation(title: title, isPinned: isPinned, updatedAt: now.addingTimeInterval(TimeInterval(-86_400 * daysAgo)))
    }

    @Test func `chats are grouped by age with pinned ones first`() {
        let conversations = [
            conversation("Fresh", daysAgo: 0),
            conversation("Old but pinned", daysAgo: 40, isPinned: true),
            conversation("Yesterday", daysAgo: 1),
            conversation("This week", daysAgo: 5),
            conversation("Ancient", daysAgo: 40)
        ]

        let groups = ConversationGrouper().groups(from: conversations, query: "", now: now, calendar: calendar)

        #expect(groups.map(\.id) == [.pinned, .today, .yesterday, .previousWeek, .earlier])
        #expect(groups.map { $0.rows.map(\.title) } == [["Old but pinned"], ["Fresh"], ["Yesterday"], ["This week"], ["Ancient"]])
    }

    @Test func `a search matches titles and message text, whatever the case`() {
        let withText = Conversation(title: "Dinner", messages: [Message(role: .user, text: "Slow LAMB shoulder")], updatedAt: now)
        let conversations = [withText, conversation("Lamb prices", daysAgo: 0), conversation("Backups", daysAgo: 0)]

        let groups = ConversationGrouper().groups(from: conversations, query: " lamb ", now: now, calendar: calendar)

        #expect(groups.flatMap(\.rows).map(\.title) == ["Dinner", "Lamb prices"])
    }
}
