import Foundation
import HearthDomain
@testable import HearthUI
import Testing

@MainActor
struct LockPresenterTests {
    /// The switch in Settings, the person holding the phone, and how often they were asked.
    @MainActor
    final class Fixture {
        var isEnabled: Bool
        var isOwner = true
        private(set) var promptCount = 0

        init(isEnabled: Bool) {
            self.isEnabled = isEnabled
        }

        func makeTestSubject() -> LockPresenter {
            let authentication = AuthenticationProvider { _ in
                await self.answerPrompt()
            }
            return LockPresenter(authentication: authentication) { self.isEnabled }
        }

        private func answerPrompt() -> Bool {
            promptCount += 1
            return isOwner
        }
    }

    @Test(arguments: [true, false])
    func `the app starts locked only when the lock is on`(isEnabled: Bool) {
        let subject = Fixture(isEnabled: isEnabled).makeTestSubject()

        #expect(subject.viewModel.isLocked == isEnabled)
    }

    @Test func `coming forward asks once and opens for the owner`() async {
        let fixture = Fixture(isEnabled: true)
        let subject = fixture.makeTestSubject()

        await subject.sceneAction(.active)

        #expect(!subject.viewModel.isLocked)
        #expect(fixture.promptCount == 1)
    }

    @Test func `a refusal keeps it locked and does not ask again until the owner does`() async {
        let fixture = Fixture(isEnabled: true)
        let subject = fixture.makeTestSubject()
        fixture.isOwner = false

        await subject.sceneAction(.active)
        await subject.sceneAction(.inactive)
        await subject.sceneAction(.active)

        #expect(subject.viewModel.isLocked)
        #expect(fixture.promptCount == 1)

        fixture.isOwner = true
        await subject.unlockAction()

        #expect(!subject.viewModel.isLocked)
        #expect(fixture.promptCount == 2)
    }

    @Test func `going to the background locks, and returning asks again`() async {
        let fixture = Fixture(isEnabled: true)
        let subject = fixture.makeTestSubject()
        await subject.sceneAction(.active)

        await subject.sceneAction(.background)
        #expect(subject.viewModel.isLocked)

        await subject.sceneAction(.active)
        #expect(!subject.viewModel.isLocked)
        #expect(fixture.promptCount == 2)
    }

    @Test func `stepping out of focus hides the conversations without locking`() async {
        let fixture = Fixture(isEnabled: true)
        let subject = fixture.makeTestSubject()
        await subject.sceneAction(.active)

        await subject.sceneAction(.inactive)

        #expect(subject.viewModel.isObscured)
        #expect(!subject.viewModel.isLocked)

        await subject.sceneAction(.active)
        #expect(!subject.viewModel.isObscured)
        #expect(fixture.promptCount == 1)
    }

    @Test func `with the lock off nothing is hidden and no one is asked`() async {
        let fixture = Fixture(isEnabled: false)
        let subject = fixture.makeTestSubject()

        await subject.sceneAction(.background)
        await subject.sceneAction(.inactive)
        await subject.sceneAction(.active)

        #expect(!subject.viewModel.isLocked)
        #expect(!subject.viewModel.isObscured)
        #expect(fixture.promptCount == 0)
    }

    @Test func `turning the lock off opens an app that was locked`() async {
        let fixture = Fixture(isEnabled: true)
        let subject = fixture.makeTestSubject()
        fixture.isEnabled = false

        await subject.sceneAction(.active)

        #expect(!subject.viewModel.isLocked)
        #expect(fixture.promptCount == 0)
    }
}

struct ConversationGrouperTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }

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
