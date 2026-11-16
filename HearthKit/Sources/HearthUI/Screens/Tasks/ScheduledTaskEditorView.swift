import HearthDomain
import SwiftUI

/// The sheet that makes or edits a scheduled task: its title and question, the cloud model, when it runs, whether
/// the web is searched first, and, for one that exists, a way to delete it.
struct ScheduledTaskEditorView: View {
    let presenter: ScheduledTasksPresenter

    var body: some View {
        @Bindable var viewModel = presenter.viewModel
        NavigationStack {
            Form {
                Section(Strings.taskTitle) {
                    TextField(Strings.taskTitlePlaceholder, text: $viewModel.title)
                        .font(.hearth(.body))
                        .accessibilityLabel(Strings.taskTitle)
                }
                Section(Strings.taskPrompt) {
                    TextField(Strings.taskPromptPlaceholder, text: $viewModel.prompt, axis: .vertical)
                        .font(.hearth(.body))
                        .lineLimit(3...10)
                        .accessibilityLabel(Strings.taskPrompt)
                }
                modelSection(models: presenter.modelChoices, selection: $viewModel.modelID)
                scheduleSection(viewModel: $viewModel)
                Section {
                    Toggle(isOn: $viewModel.usesWebSearch) {
                        VStack(alignment: .leading, spacing: HearthSpacing.s2) {
                            Text(Strings.taskWebSearch)
                                .font(.hearth(.body))
                            Text(Strings.taskWebSearchDetail)
                                .font(.hearth(.footnote))
                                .foregroundStyle(HearthColor.mute)
                        }
                    }
                    .tint(HearthColor.pine)
                    .accessibilityLabel(Strings.taskWebSearch)
                }
                // Only a task that exists can be deleted, so a new one has no such section at all.
                if viewModel.isExisting {
                    Section {
                        Button(Strings.deleteTask, role: .destructive) { viewModel.isConfirmingDelete = true }
                            .accessibilityLabel(Strings.deleteTask)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(HearthColor.paper)
            .navigationTitle(viewModel.isExisting ? Strings.editTask : Strings.newTask)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Strings.cancel, action: presenter.cancelAction)
                        .foregroundStyle(HearthColor.mute)
                        .accessibilityLabel(Strings.cancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(Strings.done) { Task { await presenter.saveAction() } }
                        .fontWeight(.semibold)
                        .foregroundStyle(viewModel.canSave ? HearthColor.pine : HearthColor.mute)
                        .disabled(!viewModel.canSave)
                        .accessibilityLabel(Strings.done)
                }
            }
        }
        .tint(HearthColor.pine)
        .confirmationDialog(Strings.deleteTaskQuestion, isPresented: $viewModel.isConfirmingDelete, titleVisibility: .visible) {
            Button(Strings.deleteTask, role: .destructive) {
                Haptics.play(.warning)
                Task { await presenter.deleteAction() }
            }
            Button(Strings.cancel, role: .cancel) {}
        }
    }

    /// The cloud models to choose from, or a line saying there are none.
    private func modelSection(models: [ChatModel], selection: Binding<ChatModel.ID?>) -> some View {
        Section {
            Picker(Strings.taskModel, selection: selection) {
                Text(Strings.taskModelChoose).tag(ChatModel.ID?.none)
                ForEach(models) { model in
                    Text(ScheduledTasksPresenter.modelName(model.id)).tag(ChatModel.ID?.some(model.id))
                }
            }
            .font(.hearth(.body))
            .accessibilityLabel(Strings.taskModel)
            // Automatic is always offered; this says when the server lists no cloud model to choose besides. A form
            // row cannot fold to nothing, so it is left out rather than hidden.
            if !presenter.hasListedCloudModels {
                Text(Strings.taskNoCloudModels)
                    .font(.hearth(.footnote))
                    .foregroundStyle(HearthColor.mute)
                    .listRowSeparator(.hidden)
            }
        } footer: {
            Text(selection.wrappedValue == ScheduledTask.automaticModelID ? Strings.taskModelAutomaticDetail : Strings.taskModelFooter)
        }
    }

    /// How often it runs, and the controls that kind of schedule needs. Each control stays in the form and is folded
    /// away when its kind is not chosen.
    private func scheduleSection(viewModel: Bindable<ScheduledTasksViewModel>) -> some View {
        let kind = viewModel.wrappedValue.scheduleKind
        return Section(Strings.taskSchedule) {
            Picker(Strings.taskSchedule, selection: viewModel.scheduleKind) {
                ForEach(TaskScheduleKind.allCases, id: \.self) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel(Strings.taskSchedule)
            if kind == .weekly {
                Picker(Strings.taskWeekday, selection: viewModel.weekday) {
                    ForEach(presenter.weekdays, id: \.number) { day in
                        Text(day.name).tag(day.number)
                    }
                }
                .font(.hearth(.body))
                .accessibilityLabel(Strings.taskWeekday)
            }
            if kind == .once {
                DatePicker(Strings.taskDate, selection: viewModel.onceDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                    .font(.hearth(.body))
                    .accessibilityLabel(Strings.taskDate)
            } else {
                DatePicker(Strings.taskTime, selection: viewModel.time, displayedComponents: .hourAndMinute)
                    .font(.hearth(.body))
                    .accessibilityLabel(Strings.taskTime)
            }
        }
    }
}
