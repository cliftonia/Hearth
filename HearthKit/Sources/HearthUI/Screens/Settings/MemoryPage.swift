import HearthDomain
import SwiftUI

/// What is remembered about the user: the switch, a memory added by hand, the list, and forgetting everything.
/// A memory is deleted by swiping it, from its menu (touch and hold, or a secondary click on a Mac), or with Edit.
struct MemoryPage: View {
    let presenter: SettingsPresenter

    /// Whether the list is being edited. Kept here, rather than left to the navigation, so that editing can end by
    /// itself once the last memory is gone and Edit can no longer be tapped.
    @State private var editMode: EditMode = .inactive

    var body: some View {
        @Bindable var viewModel = presenter.viewModel
        let memories = presenter.memories
        Form {
            Section {
                Toggle(Strings.memoryToggle, isOn: $viewModel.isMemoryEnabled)
                    .font(.hearth(.body))
                    .onChange(of: viewModel.isMemoryEnabled) { presenter.keepAction() }
                    .accessibilityLabel(Strings.memoryToggle)
            } footer: {
                Text(Strings.memoryFooter)
            }
            Section {
                TextField(Strings.memoryPlaceholder, text: $viewModel.newMemoryText, axis: .vertical)
                    .lineLimit(1...3)
                    .accessibilityLabel(Strings.addMemory)
                Button(Strings.addMemory) { Task { await presenter.addMemoryAction() } }
                    .foregroundStyle(HearthColor.pine)
                    .disabled(viewModel.newMemoryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel(Strings.addMemory)
            } footer: {
                Text(Strings.memoryListFooter)
            }
            Section {
                ForEach(memories) { memory in
                    memoryRow(memory)
                }
                .onDelete { offsets in
                    let ids = offsets.map { memories[$0].id }
                    Task {
                        for id in ids {
                            await presenter.deleteMemoryAction(id)
                        }
                    }
                }
                // A row of a list keeps its height however small its content, so the line is left out, not hidden.
                if memories.isEmpty {
                    Text(Strings.noMemories)
                        .foregroundStyle(HearthColor.mute)
                        .deleteDisabled(true)
                }
            }
            Section {
                Button(Strings.clearMemories, role: .destructive) { viewModel.isConfirmingClearMemories = true }
                    .foregroundStyle(memories.isEmpty ? HearthColor.mute : HearthColor.danger)
                    .disabled(memories.isEmpty)
                    .accessibilityLabel(Strings.clearMemories)
            }
        }
        .scrollContentBackground(.hidden)
        .background(HearthColor.paper)
        .navigationTitle(Strings.memory)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                EditButton()
                    .disabled(memories.isEmpty && !editMode.isEditing)
            }
        }
        .environment(\.editMode, $editMode)
        .onChange(of: memories.isEmpty) { _, isEmpty in
            editMode = Self.editMode(editMode, whenListIsEmpty: isEmpty)
        }
        .confirmationDialog(Strings.clearMemoriesQuestion, isPresented: $viewModel.isConfirmingClearMemories, titleVisibility: .visible) {
            Button(Strings.clearMemories, role: .destructive) {
                Haptics.play(.warning)
                Task { await presenter.clearMemoriesAction() }
            }
            Button(Strings.cancel, role: .cancel) {}
        }
    }

    /// How editing stands once the list has changed: an emptied list has nothing left to edit, so editing ends.
    nonisolated static func editMode(_ mode: EditMode, whenListIsEmpty isEmpty: Bool) -> EditMode {
        isEmpty ? .inactive : mode
    }

    /// One memory, with Delete in its menu and among its VoiceOver actions.
    private func memoryRow(_ memory: Memory) -> some View {
        Text(memory.text)
            .font(.hearth(.body))
            .foregroundStyle(HearthColor.ink)
            .contextMenu {
                Button(role: .destructive, action: { Task { await presenter.deleteMemoryAction(memory.id) } }, label: {
                    Label(Strings.delete, systemImage: "trash")
                })
            }
            .accessibilityAction(named: Strings.delete) {
                Task { await presenter.deleteMemoryAction(memory.id) }
            }
    }
}
