import Foundation
import HearthDomain
@testable import HearthUI
import Testing

/// The scheduled tasks page and its editor: what the list says, what can be added without sync, and what is kept.
@MainActor
struct ScheduledTasksPresenterTests {
    /// Monday 16 November 2026, 10:15 in Brisbane.
    static let now = Date(timeIntervalSince1970: 1_794_788_100)

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Australia/Brisbane")!
        calendar.locale = Locale(identifier: "en_GB")
        return calendar
    }

    /// The presenter with stores in memory and a record of what was saved.
    @MainActor
    final class Fixture {
        let syncStore: SyncStore
        let modelStore = ModelStore { _ in
            ["llama3.2:latest", "gpt-oss:120b-cloud", "kimi-k2:1t-cloud"].map { ChatModel(id: ChatModel.ID($0)) }
        }
        let saved = SavedTasks()
        let taskStore: TaskStore

        init(isSyncOn: Bool = true, tasks: [ScheduledTask] = []) {
            syncStore = PresenterFixtures.syncStore(SyncSettings(hubAddress: "http://hub.local:8765", isEnabled: isSyncOn))
            let saved = saved
            taskStore = TaskStore(provider: TaskDataProvider(
                loadAll: { tasks },
                save: { saved.save($0) },
                delete: { saved.delete($0) }
            ), clock: { ScheduledTasksPresenterTests.now })
        }

        func makeTestSubject() async -> ScheduledTasksPresenter {
            try? await taskStore.load()
            try? await modelStore.refresh(settings: ServerSettings(ollamaAddress: "http://models.local"))
            return ScheduledTasksPresenter(dependencies: ScheduledTasksPresenter.Dependencies(
                taskStore: taskStore,
                syncStore: syncStore,
                modelStore: modelStore,
                now: { ScheduledTasksPresenterTests.now },
                calendar: { ScheduledTasksPresenterTests.calendar }
            ))
        }
    }

    /// What the store wrote, safely across tasks.
    final class SavedTasks: @unchecked Sendable {
        private let lock = NSLock()
        private var stored: [ScheduledTask.ID: ScheduledTask] = [:]

        func save(_ task: ScheduledTask) {
            lock.withLock { stored[task.id] = task }
        }

        func delete(_ id: ScheduledTask.ID) {
            lock.withLock { stored[id] = nil }
        }

        var all: [ScheduledTask] { lock.withLock { Array(stored.values) } }
    }

    static func task(_ title: String, schedule: TaskSchedule, lastRunAt: Date? = nil, failed: Bool = false) -> ScheduledTask {
        ScheduledTask(
            title: title, prompt: "Ask", modelID: ChatModel.ID("gpt-oss:120b-cloud"), schedule: schedule,
            lastRunAt: lastRunAt, lastRunFailed: failed, createdAt: now, updatedAt: now
        )
    }

    // MARK: Words

    @Test func `a schedule is put in plain words`() {
        let formatter = TaskScheduleFormatter(calendar: Self.calendar, now: Self.now)
        let calendar = Self.calendar
        let once = calendar.date(from: DateComponents(year: 2026, month: 11, day: 20, hour: 9, minute: 0))!

        #expect(formatter.description(of: .daily(TaskTimeOfDay(hour: 7, minute: 30)!, timeZone: "Australia/Brisbane")) == "Every day at 7:30")
        #expect(formatter.description(of: .weekly(TaskTimeOfDay(hour: 18, minute: 0)!, weekday: 5, timeZone: "Australia/Brisbane")) == "Every Friday at 18:00")
        #expect(formatter.description(of: .once(once)) == "Once, 20 Nov at 9:00")
    }

    @Test func `a twelve-hour clock is followed where the language uses one`() {
        var calendar = Self.calendar
        calendar.locale = Locale(identifier: "en_US")
        let formatter = TaskScheduleFormatter(calendar: calendar, now: Self.now)

        #expect(formatter.description(of: .daily(TaskTimeOfDay(hour: 19, minute: 5)!, timeZone: "America/New_York")) == "Every day at 7:05 PM")
        #expect(formatter.weekdayName(7) == "Sunday")
        #expect(formatter.weekdayName(1) == "Monday")
    }

    @Test func `the last run says when, that it failed, or that there has been none`() {
        let formatter = TaskScheduleFormatter(calendar: Self.calendar, now: Self.now)
        let schedule = TaskSchedule.daily(TaskTimeOfDay(hour: 7, minute: 30)!, timeZone: "Australia/Brisbane")
        let today = Self.calendar.date(bySettingHour: 7, minute: 30, second: 0, of: Self.now)!
        let yesterday = Self.calendar.date(byAdding: .day, value: -1, to: today)!
        let lastWeek = Self.calendar.date(byAdding: .day, value: -4, to: today)!

        #expect(formatter.lastRun(of: Self.task("A", schedule: schedule, lastRunAt: today)) == "Ran today at 7:30")
        #expect(formatter.lastRun(of: Self.task("A", schedule: schedule, lastRunAt: yesterday)) == "Ran yesterday at 7:30")
        #expect(formatter.lastRun(of: Self.task("A", schedule: schedule, lastRunAt: lastWeek)) == "Ran 12 Nov at 7:30")
        #expect(formatter.lastRun(of: Self.task("A", schedule: schedule, lastRunAt: today, failed: true)) == "Last run failed")
        #expect(formatter.lastRun(of: Self.task("A", schedule: schedule)) == "Not run yet")
    }

    // MARK: The page

    @Test func `the list shows each task's schedule, last run and switch`() async {
        let schedule = TaskSchedule.daily(TaskTimeOfDay(hour: 7, minute: 30)!, timeZone: "Australia/Brisbane")
        let fixture = Fixture(tasks: [Self.task("Briefing", schedule: schedule)])
        let subject = await fixture.makeTestSubject()

        #expect(subject.rows.map(\.title) == ["Briefing"])
        #expect(subject.rows.first?.scheduleText == "Every day at 7:30")
        #expect(subject.rows.first?.lastRunText == "Not run yet")
        #expect(subject.rows.first?.isEnabled == true)
    }

    @Test func `without sync nothing can be added`() async {
        let fixture = Fixture(isSyncOn: false)
        let subject = await fixture.makeTestSubject()

        #expect(!subject.isSyncOn)
        subject.addAction()
        #expect(!subject.viewModel.isEditorPresented)
    }

    @Test func `switching a task off keeps it, stamped for sync`() async {
        let schedule = TaskSchedule.daily(TaskTimeOfDay(hour: 7, minute: 30)!, timeZone: "Australia/Brisbane")
        let briefing = Self.task("Briefing", schedule: schedule)
        let fixture = Fixture(tasks: [briefing])
        let subject = await fixture.makeTestSubject()

        await subject.setEnabledAction(briefing.id, isEnabled: false)

        #expect(fixture.taskStore.task(for: briefing.id)?.isEnabled == false)
        #expect(fixture.saved.all.map(\.isEnabled) == [false])
    }

    // MARK: The editor

    @Test func `a new task lets the hub choose, offers only cloud models besides, and is saved in the device's time zone`() async throws {
        let fixture = Fixture()
        let subject = await fixture.makeTestSubject()

        subject.addAction()
        #expect(subject.viewModel.isEditorPresented)
        #expect(subject.modelChoices.map(\.id.rawValue) == ["auto", "gpt-oss:120b-cloud", "kimi-k2:1t-cloud"])
        #expect(subject.viewModel.modelID == ScheduledTask.automaticModelID)
        #expect(ScheduledTasksPresenter.modelName(ScheduledTask.automaticModelID) == "Automatic")
        #expect(!subject.viewModel.canSave)

        subject.viewModel.title = "  Weekend weather "
        subject.viewModel.prompt = "What will the weather be?"
        subject.viewModel.scheduleKind = .weekly
        subject.viewModel.weekday = 5
        subject.viewModel.time = Self.calendar.date(bySettingHour: 18, minute: 0, second: 0, of: Self.now)!
        subject.viewModel.usesWebSearch = true
        await subject.saveAction()

        let saved = try #require(fixture.saved.all.first)
        #expect(!subject.viewModel.isEditorPresented)
        #expect(saved.title == "Weekend weather")
        #expect(saved.schedule == .weekly(TaskTimeOfDay(hour: 18, minute: 0)!, weekday: 5, timeZone: "Australia/Brisbane"))
        #expect(saved.usesWebSearch && saved.isEnabled)
        #expect(saved.modelID == ScheduledTask.automaticModelID)
        #expect(subject.rows.first?.scheduleText == "Every Friday at 18:00")
        #expect(subject.rows.first?.modelName == "Automatic")
    }

    @Test func `editing keeps the task's model even when the server no longer lists it, and the hub's record of its runs`() async throws {
        let ran = Self.now.addingTimeInterval(-3_600)
        let task = ScheduledTask(
            title: "Briefing", prompt: "News?", modelID: ChatModel.ID("retired-model:cloud"),
            schedule: .once(Self.now.addingTimeInterval(86_400)), lastRunAt: ran, createdAt: Self.now, updatedAt: Self.now
        )
        let fixture = Fixture(tasks: [task])
        let subject = await fixture.makeTestSubject()

        subject.editAction(task.id)
        #expect(subject.viewModel.isExisting)
        #expect(subject.viewModel.scheduleKind == .once)
        #expect(subject.modelChoices.map(\.id.rawValue).prefix(2) == ["auto", "retired-model:cloud"])
        subject.viewModel.prompt = "Headlines?"
        await subject.saveAction()

        let saved = try #require(fixture.taskStore.task(for: task.id))
        #expect(saved.prompt == "Headlines?")
        #expect(saved.modelID == ChatModel.ID("retired-model:cloud"))
        #expect(saved.lastRunAt == ran)
        #expect(saved.createdAt == task.createdAt)
    }

    @Test func `opening a task that has already run once keeps its date, so saving it does not run it again`() async throws {
        let ranAt = Self.now.addingTimeInterval(-7_200)
        let task = ScheduledTask(
            title: "Briefing", prompt: "News?", modelID: ChatModel.ID("auto"),
            schedule: .once(ranAt), lastRunAt: ranAt, createdAt: ranAt, updatedAt: ranAt
        )
        let fixture = Fixture(tasks: [task])
        let subject = await fixture.makeTestSubject()

        subject.editAction(task.id)
        #expect(subject.viewModel.onceDate == ranAt)
        #expect(subject.viewModel.earliestOnceDate == ranAt)
        subject.viewModel.title = "Morning briefing"
        await subject.saveAction()

        let saved = try #require(fixture.taskStore.task(for: task.id))
        #expect(saved.schedule == .once(ranAt))
    }

    @Test func `the list names a cloud model as the model picker does, without its cloud tag`() {
        #expect(ScheduledTasksPresenter.modelName(ChatModel.ID("deepseek-v4.1-flash:cloud")) == "deepseek-v4.1-flash")
        #expect(ScheduledTasksPresenter.modelName(ChatModel.ID("kimi-k2:1t-cloud")) == "kimi-k2:1t-cloud")
    }

    @Test func `a new task that runs once cannot be set in the past`() async {
        let subject = await Fixture().makeTestSubject()

        subject.addAction()

        #expect(subject.viewModel.earliestOnceDate == Self.now)
    }

    @Test func `deleting from the editor removes the task and closes it`() async {
        let schedule = TaskSchedule.daily(TaskTimeOfDay(hour: 7, minute: 30)!, timeZone: "Australia/Brisbane")
        let briefing = Self.task("Briefing", schedule: schedule)
        let fixture = Fixture(tasks: [briefing])
        let subject = await fixture.makeTestSubject()

        subject.editAction(briefing.id)
        await subject.deleteAction()

        #expect(fixture.taskStore.tasks.isEmpty)
        #expect(!subject.viewModel.isEditorPresented)
    }

    @Test func `with no cloud model on the server the hub's own choice is still offered`() async {
        let fixture = Fixture()
        let subject = ScheduledTasksPresenter(dependencies: ScheduledTasksPresenter.Dependencies(
            taskStore: fixture.taskStore,
            syncStore: fixture.syncStore,
            modelStore: ModelStore { _ in [ChatModel(id: ChatModel.ID("llama3.2:latest"))] },
            now: { Self.now },
            calendar: { Self.calendar }
        ))

        subject.addAction()
        subject.viewModel.title = "Briefing"
        subject.viewModel.prompt = "News?"

        #expect(subject.modelChoices.map(\.id) == [ScheduledTask.automaticModelID])
        #expect(subject.viewModel.modelID == ScheduledTask.automaticModelID)
        #expect(subject.viewModel.canSave)
    }
}
