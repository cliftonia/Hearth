import HearthDomain
import SwiftUI

/// The scheduled tasks: each with its schedule, how its last run went and a switch, and a way to add one. Without
/// sync the page says that tasks run on the hub and leads to the sync page.
struct ScheduledTasksPage: View {
    let presenter: ScheduledTasksPresenter
    /// Opens another settings page; here, the sync page.
    let openAction: (SettingsPageKind) -> Void

    var body: some View {
        @Bindable var viewModel = presenter.viewModel
        let isSyncOn = presenter.isSyncOn
        let rows = presenter.rows
        SettingsPage(title: Strings.tasks) {
            // The notice and the card share a stack whose gap closes with the notice, so no space is left above the
            // card while sync is on.
            VStack(alignment: .leading, spacing: isSyncOn ? 0 : HearthSpacing.s24) {
                syncNotice
                    .folded(isSyncOn)
                tasksCard(rows: rows, isSyncOn: isSyncOn)
            }
        }
        // The editor is pushed within the settings, rather than stacked over them as a second sheet.
        .navigationDestination(isPresented: $viewModel.isEditorPresented) {
            ScheduledTaskEditorForm(presenter: presenter)
                .navigationBarBackButtonHidden()
        }
        .alert(Strings.taskActionFailed, isPresented: $viewModel.isShowingFailure) {
            Button(Strings.ok, role: .cancel) {}
        }
    }

    /// The tasks, a line when there are none, and the way to add one.
    private func tasksCard(rows: [TaskRowViewConfiguration], isSyncOn: Bool) -> some View {
        SettingsCard(footer: Strings.tasksFooter) {
            ForEach(rows) { row in
                TaskRow(row: row, presenter: presenter)
                Hairline()
                    .padding(.leading, HearthSpacing.s16)
            }
            Text(Strings.tasksEmpty)
                .font(.hearth(.body))
                .foregroundStyle(HearthColor.mute)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, HearthSpacing.s16)
                .padding(.vertical, rows.isEmpty ? HearthSpacing.s14 : 0)
                .folded(!rows.isEmpty)
            Hairline()
                .padding(.leading, HearthSpacing.s16)
                .opacity(rows.isEmpty ? 1 : 0)
            addButton(isEnabled: isSyncOn)
        }
    }

    /// Says why nothing can be added, and leads to where sync is turned on.
    private var syncNotice: some View {
        PermissionNotice(systemImage: "arrow.triangle.2.circlepath", message: Strings.tasksNeedSync, actionTitle: Strings.tasksOpenSync) {
            openAction(.sync)
        }
    }

    private func addButton(isEnabled: Bool) -> some View {
        Button(action: presenter.addAction) {
            Label(Strings.tasksAdd, systemImage: "plus")
                .font(.hearth(.body))
                .foregroundStyle(isEnabled ? HearthColor.pine : HearthColor.mute)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, HearthSpacing.s16)
                .padding(.vertical, HearthSpacing.s14)
                .contentShape(Rectangle())
                .hoverHighlight(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(Strings.tasksAdd)
    }
}

/// One task: its title, schedule and last run, which open it in the editor (as the chevron after them says), and its
/// switch.
private struct TaskRow: View {
    let row: TaskRowViewConfiguration
    let presenter: ScheduledTasksPresenter

    /// The switch's own state, set from the task and kept by the store once thrown.
    @State private var isOn = true

    var body: some View {
        HStack(spacing: HearthSpacing.s12) {
            Button(action: { presenter.editAction(row.id) }, label: {
                HStack(spacing: HearthSpacing.s8) {
                    details
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right")
                        .font(.hearth(.footnote).weight(.semibold))
                        .foregroundStyle(HearthColor.mute)
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
                .hoverHighlight(RoundedRectangle(cornerRadius: HearthRadius.row, style: .continuous).inset(by: -HearthSpacing.s6))
            })
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Strings.taskRowLabel(title: row.title, schedule: row.scheduleText, model: row.modelName, lastRun: row.lastRunText))
            .accessibilityHint(Strings.editTask)
            Toggle(Strings.taskEnabled, isOn: $isOn)
                .labelsHidden()
                .tint(HearthColor.pine)
                .accessibilityLabel(Strings.taskEnabledLabel(title: row.title))
        }
        .padding(.horizontal, HearthSpacing.s16)
        .padding(.vertical, HearthSpacing.s12)
        .onAppear { isOn = row.isEnabled }
        .onChange(of: row.isEnabled) { isOn = row.isEnabled }
        .onChange(of: isOn) {
            guard isOn != row.isEnabled else {
                return
            }
            Task { await presenter.setEnabledAction(row.id, isEnabled: isOn) }
        }
    }

    /// The title, the schedule and model, and how the last run went.
    private var details: some View {
        VStack(alignment: .leading, spacing: HearthSpacing.s2) {
            Text(row.title)
                .font(.hearth(.body))
                .foregroundStyle(HearthColor.ink)
                .lineLimit(2)
            Text(Strings.taskScheduleAndModel(schedule: row.scheduleText, model: row.modelName))
                .font(.hearth(.footnote))
                .foregroundStyle(HearthColor.mute)
            Text(row.lastRunText)
                .font(.hearth(.footnote))
                .foregroundStyle(row.lastRunFailed ? HearthColor.danger : HearthColor.mute)
        }
    }
}
