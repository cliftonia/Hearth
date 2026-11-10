import HearthDomain
import SwiftUI

/// What is remembered about the user: a switch, a way in to the list, and the list itself.
struct MemorySection: View {
    let presenter: SettingsPresenter

    var body: some View {
        @Bindable var viewModel = presenter.viewModel
        Section {
            Toggle(Strings.memoryToggle, isOn: $viewModel.isMemoryEnabled)
            NavigationLink(destination: { MemoryListView(presenter: presenter) }, label: {
                HStack(spacing: 8) {
                    Text(Strings.savedMemories)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(presenter.memories.count)")
                        .foregroundStyle(HearthColor.mute)
                }
            })
        } header: {
            Text(Strings.memory)
        } footer: {
            Text(Strings.memoryFooter)
        }
    }
}

private struct MemoryListView: View {
    let presenter: SettingsPresenter

    var body: some View {
        @Bindable var viewModel = presenter.viewModel
        let memories = presenter.memories
        Form {
            Section {
                TextField(Strings.memoryPlaceholder, text: $viewModel.newMemoryText, axis: .vertical)
                    .lineLimit(1...3)
                    .accessibilityLabel(Strings.addMemory)
                Button(Strings.addMemory) { Task { await presenter.addMemoryAction() } }
                    .foregroundStyle(HearthColor.pine)
                    .disabled(viewModel.newMemoryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } footer: {
                Text(Strings.memoryListFooter)
            }
            Section {
                ForEach(memories) { memory in
                    Text(memory.text)
                        .font(.body)
                        .foregroundStyle(HearthColor.ink)
                        .swipeActions {
                            Button(Strings.delete, role: .destructive) {
                                Task { await presenter.deleteMemoryAction(memory.id) }
                            }
                        }
                }
                Text(Strings.noMemories)
                    .foregroundStyle(HearthColor.mute)
                    .opacity(memories.isEmpty ? 1 : 0)
                    .frame(height: memories.isEmpty ? nil : 0)
                    .accessibilityHidden(!memories.isEmpty)
                    .listRowSeparator(.hidden)
            }
            Section {
                Button(Strings.clearMemories, role: .destructive) { viewModel.isConfirmingClearMemories = true }
                    .disabled(memories.isEmpty)
            }
        }
        .scrollContentBackground(.hidden)
        .background(HearthColor.paper)
        .navigationTitle(Strings.savedMemories)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(Strings.clearMemoriesQuestion, isPresented: $viewModel.isConfirmingClearMemories, titleVisibility: .visible) {
            Button(Strings.clearMemories, role: .destructive) { Task { await presenter.clearMemoriesAction() } }
            Button(Strings.cancel, role: .cancel) {}
        }
    }
}
