import Foundation
import HearthCore
import HearthDomain
import os

/// What the tasks tell the coordinator, for the editor and the notice it shows over the chat.
@MainActor
protocol ScheduledTasksPresenterDelegate: AnyObject {
    /// The editor was closed: by Cancel, by saving or by deleting.
    func scheduledTasksPresenterDidCloseEditor(_ presenter: ScheduledTasksPresenter)
    /// The notice that tasks need sync was answered with Set up sync.
    func scheduledTasksPresenterDidRequestSync(_ presenter: ScheduledTasksPresenter)
}

/// The scheduled tasks page in the settings, and the sheet that makes or edits a task.
///
/// Tasks run on the hub, so nothing can be added while sync is off; the page says so and leads to the sync page,
/// which is the settings' own navigation. Every change is kept at once through `TaskStore`, which sync then sends.
/// A task can also be begun from the composer's + menu, with what was being written as its question; the
/// coordinator then shows the editor over the chat, or, while sync is off, the notice.
@MainActor
final class ScheduledTasksPresenter {
    /// What the page is built from.
    struct Dependencies {
        let taskStore: TaskStore
        let syncStore: SyncStore
        /// The models the chat server offers, from which the cloud ones are picked.
        let modelStore: ModelStore
        let now: @MainActor () -> Date
        /// The device's calendar, carrying its time zone and language, which a new schedule is set in.
        let calendar: @MainActor () -> Calendar
    }

    let viewModel = ScheduledTasksViewModel()
    let dependencies: Dependencies
    weak var delegate: (any ScheduledTasksPresenterDelegate)?
    private let logger = Logger(for: ScheduledTasksPresenter.self)

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    private var taskStore: TaskStore { dependencies.taskStore }

    // MARK: The page

    /// Whether tasks can be added: they live on the hub, so sync must be on.
    var isSyncOn: Bool {
        dependencies.syncStore.settings.isActive
    }

    /// What the row in the settings says: "2 active", "None", or "Needs sync".
    var rowStatus: String {
        guard isSyncOn else {
            return Strings.tasksNeedsSync
        }
        let tasks = taskStore.tasks
        guard !tasks.isEmpty else {
            return Strings.tasksNone
        }
        return Strings.tasksActive(number: tasks.filter(\.isEnabled).count)
    }

    var rows: [TaskRowViewConfiguration] {
        let formatter = formatter
        return taskStore.tasks.map { task in
            TaskRowViewConfiguration(
                id: task.id,
                title: task.title,
                scheduleText: formatter.description(of: task.schedule),
                lastRunText: formatter.lastRun(of: task),
                lastRunFailed: task.lastRunFailed,
                modelName: Self.modelName(task.modelID),
                isEnabled: task.isEnabled
            )
        }
    }

    /// Turns a task on or off.
    func setEnabledAction(_ id: ScheduledTask.ID, isEnabled: Bool) async {
        guard let task = taskStore.task(for: id), task.isEnabled != isEnabled else {
            return
        }
        await keep(task.updating(isEnabled: isEnabled))
    }

    // MARK: The editor

    /// Automatic first, then the cloud models the server offers, with the draft's own model kept after Automatic if
    /// the server no longer lists it, so that editing a task never changes its model unasked.
    var modelChoices: [ChatModel] {
        let automatic = ChatModel(id: ScheduledTask.automaticModelID, isCloud: true)
        let cloud = ScheduledTask.cloudModels(from: dependencies.modelStore.models).filter { $0.id != automatic.id }
        guard let chosen = viewModel.modelID, chosen != automatic.id, !cloud.contains(where: { $0.id == chosen }) else {
            return [automatic] + cloud
        }
        return [automatic, ChatModel(id: chosen, isCloud: true)] + cloud
    }

    /// Whether the server lists any cloud model to choose besides Automatic.
    var hasListedCloudModels: Bool {
        ScheduledTask.cloudModels(from: dependencies.modelStore.models).contains { $0.id != ScheduledTask.automaticModelID }
    }

    /// A model's name as the editor shows it: "Automatic" for the hub's own choice.
    static func modelName(_ id: ChatModel.ID) -> String {
        id == ScheduledTask.automaticModelID ? Strings.taskModelAutomatic : ChatModel(id: id).displayName
    }

    /// The weekdays from Monday, numbered as the wire numbers them, with their names.
    var weekdays: [(number: Int, name: String)] {
        let formatter = formatter
        return (1...7).map { ($0, formatter.weekdayName($0)) }
    }

    /// Opens the editor on a new task: every day at the next full hour, with the hub choosing the model.
    func addAction() {
        guard isSyncOn else {
            return
        }
        fillNewTask(prompt: "")
        viewModel.isEditorPresented = true
    }

    /// Fills the editor with a new task asking what was being written in the composer, for the coordinator to show
    /// over the chat. The title is left for the user. Returns `false`, filling nothing, while sync is off.
    func beginTaskAction(prompt: String) -> Bool {
        guard isSyncOn else {
            return false
        }
        fillNewTask(prompt: prompt.trimmingCharacters(in: .whitespacesAndNewlines))
        return true
    }

    /// The notice that tasks need sync was answered with Set up sync.
    func setUpSyncAction() {
        delegate?.scheduledTasksPresenterDidRequestSync(self)
    }

    /// A new task: every day at the next full hour, with the hub choosing the model.
    private func fillNewTask(prompt: String) {
        let calendar = dependencies.calendar()
        let now = dependencies.now()
        let nextHour = calendar.date(byAdding: .hour, value: 1, to: now) ?? now
        let start = calendar.dateInterval(of: .hour, for: nextHour)?.start ?? now
        fillEditor(id: nil, with: EditorSeed(
            title: "",
            prompt: prompt,
            modelID: ScheduledTask.automaticModelID,
            schedule: .daily(Self.timeOfDay(start, calendar: calendar), timeZone: calendar.timeZone.identifier),
            usesWebSearch: false
        ))
    }

    /// Opens the editor on a task that exists.
    func editAction(_ id: ScheduledTask.ID) {
        guard let task = taskStore.task(for: id) else {
            return
        }
        fillEditor(id: id, with: EditorSeed(
            title: task.title, prompt: task.prompt, modelID: task.modelID, schedule: task.schedule, usesWebSearch: task.usesWebSearch
        ))
        viewModel.isEditorPresented = true
    }

    /// Closes the editor and lets the draft go.
    func cancelAction() {
        closeEditor()
    }

    /// Keeps the draft as a new task or as the changed one, set in the device's time zone, and closes the editor.
    func saveAction() async {
        guard viewModel.canSave, let modelID = viewModel.modelID else {
            return
        }
        let title = viewModel.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let prompt = viewModel.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let schedule = draftSchedule
        let task: ScheduledTask
        if let id = viewModel.editingID, let existing = taskStore.task(for: id) {
            task = existing.updating(title: title, prompt: prompt, modelID: modelID, schedule: schedule, usesWebSearch: viewModel.usesWebSearch)
        } else {
            let now = dependencies.now()
            task = ScheduledTask(
                title: title, prompt: prompt, modelID: modelID, schedule: schedule,
                usesWebSearch: viewModel.usesWebSearch, createdAt: now, updatedAt: now
            )
        }
        if await keep(task) {
            closeEditor()
        }
    }

    /// Deletes the task being edited, once the user has confirmed, and closes the editor.
    func deleteAction() async {
        guard let id = viewModel.editingID else {
            return
        }
        do {
            try await taskStore.delete(id)
            closeEditor()
        } catch {
            logger.error("Deleting a task failed: \(error.localizedDescription, privacy: .public)")
            viewModel.isShowingFailure = true
        }
    }

    // MARK: Helpers

    /// The schedule the editor describes, in the device's time zone.
    var draftSchedule: TaskSchedule {
        let calendar = dependencies.calendar()
        let time = Self.timeOfDay(viewModel.time, calendar: calendar)
        switch viewModel.scheduleKind {
        case .daily:
            return .daily(time, timeZone: calendar.timeZone.identifier)
        case .weekly:
            return .weekly(time, weekday: viewModel.weekday, timeZone: calendar.timeZone.identifier)
        case .once:
            return .once(calendar.dateInterval(of: .minute, for: viewModel.onceDate)?.start ?? viewModel.onceDate)
        }
    }

    private var formatter: TaskScheduleFormatter {
        TaskScheduleFormatter(calendar: dependencies.calendar(), now: dependencies.now())
    }

    /// What the editor opens with.
    private struct EditorSeed {
        let title: String
        let prompt: String
        let modelID: ChatModel.ID?
        let schedule: TaskSchedule
        let usesWebSearch: Bool
    }

    /// Fills the editor from a task, or from a new one's starting values.
    private func fillEditor(id: ScheduledTask.ID?, with seed: EditorSeed) {
        let calendar = dependencies.calendar()
        let now = dependencies.now()
        viewModel.editingID = id
        viewModel.title = seed.title
        viewModel.prompt = seed.prompt
        viewModel.modelID = seed.modelID
        viewModel.usesWebSearch = seed.usesWebSearch
        viewModel.weekday = 1
        viewModel.onceDate = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        viewModel.earliestOnceDate = now
        switch seed.schedule {
        case .daily(let time, _):
            viewModel.scheduleKind = .daily
            viewModel.time = Self.date(at: time, near: now, calendar: calendar)
        case .weekly(let time, let weekday, _):
            viewModel.scheduleKind = .weekly
            viewModel.time = Self.date(at: time, near: now, calendar: calendar)
            viewModel.weekday = weekday
        case .once(let date):
            viewModel.scheduleKind = .once
            viewModel.time = date
            viewModel.onceDate = date
            viewModel.earliestOnceDate = min(date, now)
        }
        viewModel.isConfirmingDelete = false
    }

    /// Closes the editor wherever it is showing: on the tasks page, or over the chat.
    private func closeEditor() {
        viewModel.isEditorPresented = false
        delegate?.scheduledTasksPresenterDidCloseEditor(self)
    }

    /// Keeps a task, saying so on the page if it cannot be kept. Returns whether it was.
    @discardableResult
    private func keep(_ task: ScheduledTask) async -> Bool {
        do {
            try await taskStore.save(task)
            return true
        } catch {
            logger.error("Saving a task failed: \(error.localizedDescription, privacy: .public)")
            viewModel.isShowingFailure = true
            return false
        }
    }

    private static func timeOfDay(_ date: Date, calendar: Calendar) -> TaskTimeOfDay {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return TaskTimeOfDay(hour: parts.hour ?? 0, minute: parts.minute ?? 0) ?? .midnight
    }

    /// Today's date at a time on the clock, for the time picker, which shows only the hour and the minute.
    private static func date(at time: TaskTimeOfDay, near now: Date, calendar: Calendar) -> Date {
        calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: now) ?? now
    }
}
