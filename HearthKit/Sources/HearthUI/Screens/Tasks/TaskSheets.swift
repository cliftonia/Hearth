import SwiftUI

/// The sheets the coordinator shows over the chat for a task begun from the composer's + menu.
enum TaskSheetKind: Hashable, Identifiable {
    /// The editor, filled with a new task asking what was being written.
    case editor
    /// The notice that tasks need sync, shown instead of the editor while sync is off.
    case needsSync

    var id: Self { self }
}

/// The editor over the chat, which also says when a task could not be saved; on the tasks page the page says it.
struct ChatTaskEditorSheet: View {
    let presenter: ScheduledTasksPresenter

    var body: some View {
        @Bindable var viewModel = presenter.viewModel
        ScheduledTaskEditorView(presenter: presenter)
            .alert(Strings.taskActionFailed, isPresented: $viewModel.isShowingFailure) {
                Button(Strings.ok, role: .cancel) {}
            }
    }
}

/// Says that scheduled tasks run on the hub and need sync, and leads to the sync page.
struct TaskSyncNoticeSheet: View {
    let presenter: ScheduledTasksPresenter

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: HearthSpacing.s16) {
            SheetHeader(title: Strings.tasks) { dismiss() }
            PermissionNotice(
                systemImage: "arrow.triangle.2.circlepath",
                message: Strings.tasksNeedSync,
                actionTitle: Strings.tasksOpenSync,
                action: presenter.setUpSyncAction
            )
            .padding(.horizontal, HearthSpacing.s16)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .background(HearthColor.paper.ignoresSafeArea())
        .presentationDetents([.medium])
    }
}
