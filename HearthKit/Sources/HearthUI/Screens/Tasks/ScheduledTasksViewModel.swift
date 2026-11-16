import Foundation
import HearthDomain
import Observation

/// How often a task runs, as the editor's segmented control offers it.
enum TaskScheduleKind: Hashable, CaseIterable {
    case daily
    case weekly
    case once

    var title: String {
        switch self {
        case .daily:
            Strings.taskDaily
        case .weekly:
            Strings.taskWeekly
        case .once:
            Strings.taskOnce
        }
    }
}

/// One task in the list.
struct TaskRowViewConfiguration: Hashable, Identifiable {
    let id: ScheduledTask.ID
    let title: String
    /// "Every day at 7:30".
    let scheduleText: String
    /// "Ran today at 7:30", "Last run failed" or "Not run yet".
    let lastRunText: String
    let lastRunFailed: Bool
    /// The model's name, or "Automatic" when the hub chooses.
    let modelName: String
    let isEnabled: Bool
}

/// The tasks page and the sheet that makes or edits a task: the draft being edited and the state of the controls.
@MainActor
@Observable
final class ScheduledTasksViewModel {
    // MARK: Editor

    var isEditorPresented = false
    /// The task being edited; `nil` while a new one is being made.
    var editingID: ScheduledTask.ID?
    var title = ""
    var prompt = ""
    var modelID: ChatModel.ID?
    var scheduleKind: TaskScheduleKind = .daily
    /// The time of a daily or weekly task; only its hour and minute, on the device's clock, count.
    var time = Date()
    /// 1 for Monday through 7 for Sunday.
    var weekday = 1
    /// When a task that runs once is to run.
    var onceDate = Date()
    /// The earliest the date of a task that runs once may be set to: now, or the task's own date if that has passed,
    /// so that opening a task that has already run does not move it to now and have it run again.
    var earliestOnceDate = Date()
    var usesWebSearch = false
    var isConfirmingDelete = false

    // MARK: Page

    /// Whether a change could not be kept, which the page says in an alert.
    var isShowingFailure = false

    var isExisting: Bool { editingID != nil }

    /// A task needs a title, a question and a model.
    var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && modelID != nil
    }
}
