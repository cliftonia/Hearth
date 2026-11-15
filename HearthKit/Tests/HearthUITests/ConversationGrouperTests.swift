import Foundation
import HearthDomain
@testable import HearthUI
import Testing

/// How the sidebar's conversations are grouped by age and narrowed by a search or to one project.
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

    // MARK: Projects

    private let garden = Project(name: "Garden")
    private let boat = Project(name: "Boat")

    /// A conversation active today, in the given project or in none.
    private func conversation(_ title: String, in project: Project?) -> Conversation {
        Conversation(title: title, projectID: project?.id, updatedAt: now)
    }

    @Test func `every chat is listed when no project is chosen, with those in a project marked`() {
        let conversations = [conversation("Beds", in: garden), conversation("Hull", in: boat), conversation("Loose", in: nil)]

        let groups = ConversationGrouper().groups(from: conversations, projects: [garden, boat], query: "", now: now, calendar: calendar)

        #expect(groups.flatMap(\.rows).map(\.title) == ["Beds", "Hull", "Loose"])
        #expect(groups.flatMap(\.rows).map(\.isInProject) == [true, true, false])
    }

    @Test func `choosing a project lists only its chats, still grouped by age`() {
        let old = Conversation(title: "Compost", projectID: garden.id, updatedAt: now.addingTimeInterval(-86_400 * 40))
        let conversations = [conversation("Beds", in: garden), conversation("Hull", in: boat), conversation("Loose", in: nil), old]

        let groups = ConversationGrouper().groups(from: conversations, in: garden.id, projects: [garden, boat], query: "", now: now, calendar: calendar)

        #expect(groups.map(\.id) == [.today, .earlier])
        #expect(groups.map { $0.rows.map(\.title) } == [["Beds"], ["Compost"]])
    }

    @Test func `a search within a project finds only that project's chats`() {
        let conversations = [conversation("Tomato beds", in: garden), conversation("Tomato red paint", in: boat), conversation("Paths", in: garden)]

        let groups = ConversationGrouper().groups(from: conversations, in: garden.id, projects: [garden, boat], query: "tomato", now: now, calendar: calendar)

        #expect(groups.flatMap(\.rows).map(\.title) == ["Tomato beds"])
    }

    @Test func `a chat whose project has been deleted reads as an ordinary chat`() {
        let conversations = [conversation("Beds", in: garden)]

        let groups = ConversationGrouper().groups(from: conversations, projects: [boat], query: "", now: now, calendar: calendar)

        #expect(groups.flatMap(\.rows).map(\.isInProject) == [false])
    }

    @Test func `projects are listed in the order given, and a search narrows them by name`() {
        let grouper = ConversationGrouper()

        #expect(grouper.projects(from: [garden, boat], query: "").map(\.name) == ["Garden", "Boat"])
        #expect(grouper.projects(from: [garden, boat], query: " BOA ").map(\.id) == [boat.id])
    }
}
