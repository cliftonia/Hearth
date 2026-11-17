import Foundation
import HearthDomain
@testable import HearthUI
import Testing

/// A scheduled task begun from the composer's + menu, and what the row in the settings says about the tasks.
@MainActor
struct ScheduledTaskFromChatTests {
    typealias Fixture = ScheduledTasksPresenterTests.Fixture

    /// What the tasks presenter told the coordinator.
    @MainActor
    final class Recorder: ScheduledTasksPresenterDelegate {
        private(set) var closeCount = 0
        private(set) var syncRequestCount = 0

        func scheduledTasksPresenterDidCloseEditor(_ presenter: ScheduledTasksPresenter) {
            closeCount += 1
        }

        func scheduledTasksPresenterDidRequestSync(_ presenter: ScheduledTasksPresenter) {
            syncRequestCount += 1
        }
    }

    @Test func `a task begun from the composer asks what was being written and leaves the title to the user`() async throws {
        let fixture = Fixture()
        let subject = await fixture.makeTestSubject()
        let recorder = Recorder()
        subject.delegate = recorder

        #expect(subject.beginTaskAction(prompt: "  What is on in Brisbane this weekend?\n"))

        #expect(subject.viewModel.prompt == "What is on in Brisbane this weekend?")
        #expect(subject.viewModel.title.isEmpty)
        #expect(!subject.viewModel.isExisting)
        #expect(subject.viewModel.modelID == ScheduledTask.automaticModelID)
        // The editor shows over the chat, put there by the coordinator, not on the tasks page.
        #expect(!subject.viewModel.isEditorPresented)

        subject.viewModel.title = "Weekend"
        await subject.saveAction()

        let saved = try #require(fixture.saved.all.first)
        #expect(saved.prompt == "What is on in Brisbane this weekend?")
        #expect(recorder.closeCount == 1)
    }

    @Test func `without sync a task from the composer opens nothing, and Set up sync is passed on`() async {
        let fixture = Fixture(isSyncOn: false)
        let subject = await fixture.makeTestSubject()
        let recorder = Recorder()
        subject.delegate = recorder

        #expect(!subject.beginTaskAction(prompt: "Weather"))
        #expect(subject.viewModel.prompt.isEmpty)

        subject.setUpSyncAction()
        #expect(recorder.syncRequestCount == 1)
    }

    @Test func `cancelling the editor closes it wherever it shows`() async {
        let subject = await Fixture().makeTestSubject()
        let recorder = Recorder()
        subject.delegate = recorder
        _ = subject.beginTaskAction(prompt: "Weather")

        subject.cancelAction()

        #expect(recorder.closeCount == 1)
    }

    @Test func `the settings row says how many tasks are active, that there are none, or that sync is needed`() async {
        let daily = TaskSchedule.daily(TaskTimeOfDay(hour: 7, minute: 0)!, timeZone: "Australia/Brisbane")
        let first = ScheduledTasksPresenterTests.task("News", schedule: daily)
        let second = ScheduledTasksPresenterTests.task("Weather", schedule: daily)

        #expect(await Fixture(isSyncOn: false, tasks: [first]).makeTestSubject().rowStatus == "Needs sync")
        #expect(await Fixture().makeTestSubject().rowStatus == "None")
        #expect(await Fixture(tasks: [first, second]).makeTestSubject().rowStatus == "2 active")
    }
}

/// The composer's + menu hands what is being written to the coordinator, and keeps it.
@MainActor
struct ChatScheduleTaskTests {
    @MainActor
    final class Recorder: ChatPresenterDelegate {
        private(set) var prompts: [String] = []

        func chatPresenterDidRequestSidebar(_ presenter: ChatPresenter) {}
        func chatPresenterDidRequestVoice(_ presenter: ChatPresenter) {}
        func chatPresenterDidRequestSettings(_ presenter: ChatPresenter) {}
        func chatPresenter(_ presenter: ChatPresenter, didRequestProjectFor id: Conversation.ID) {}
        func chatPresenter(_ presenter: ChatPresenter, didRequestCanvasFor reference: CanvasReference) {}
        func chatPresenterDidRequestNewProject(_ presenter: ChatPresenter) {}

        func chatPresenter(_ presenter: ChatPresenter, didRequestTaskWith prompt: String) {
            prompts.append(prompt)
        }
    }

    @Test func `Schedule a task asks for one with the draft, which stays in the composer`() {
        let subject = ChatNotificationTests.Fixture().makeTestSubject()
        let recorder = Recorder()
        subject.delegate = recorder
        subject.viewModel.draft = "Summarise the news"

        subject.scheduleTaskAction()

        #expect(recorder.prompts == ["Summarise the news"])
        #expect(subject.viewModel.draft == "Summarise the news")
    }
}
