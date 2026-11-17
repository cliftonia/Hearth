import Foundation

// Whether the task in the editor has been changed since it opened, which keeps the editor from being swiped away.
extension ScheduledTasksPresenter {
    /// The task as the editor describes it now, with its schedule as it would be saved.
    var currentDraft: TaskDraft {
        let viewModel = viewModel
        return TaskDraft(
            title: viewModel.title,
            prompt: viewModel.prompt,
            modelID: viewModel.modelID,
            schedule: draftSchedule,
            usesWebSearch: viewModel.usesWebSearch
        )
    }

    /// Whether anything in the editor has been changed since it opened. While it has, the editor cannot be swiped
    /// away, and Cancel asks first.
    var hasEditorChanges: Bool {
        guard let original = viewModel.originalDraft else {
            return false
        }
        return currentDraft != original
    }
}
