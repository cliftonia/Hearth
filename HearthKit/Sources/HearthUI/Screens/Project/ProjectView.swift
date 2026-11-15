import HearthDomain
import SwiftUI
import UniformTypeIdentifiers

/// The project sheet: its name, its instructions, its reference files and, for one that exists, a way to delete it.
struct ProjectView: View {
    private static let removeButtonSide: CGFloat = 28

    let presenter: ProjectPresenter

    @State private var isFileImporterPresented = false

    var body: some View {
        @Bindable var viewModel = presenter.viewModel
        NavigationStack {
            Form {
                Section(Strings.projectName) {
                    TextField(Strings.projectNamePlaceholder, text: $viewModel.name)
                        .accessibilityLabel(Strings.projectName)
                }
                Section {
                    TextField(Strings.projectInstructionsPlaceholder, text: $viewModel.instructions, axis: .vertical)
                        .lineLimit(3...10)
                        .accessibilityLabel(Strings.projectInstructions)
                } header: {
                    Text(Strings.projectInstructions)
                } footer: {
                    Text(Strings.projectInstructionsFooter)
                }
                filesSection(documents: viewModel.documents)
                // Only a project that exists can be deleted, so a new one has no such section at all.
                if viewModel.isExisting {
                    Section {
                        Button(Strings.deleteProject, role: .destructive) { viewModel.isConfirmingDelete = true }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(HearthColor.paper)
            .navigationTitle(viewModel.isExisting ? Strings.editProject : Strings.newProject)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Strings.cancel, action: presenter.cancelAction)
                        .foregroundStyle(HearthColor.mute)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(Strings.done) { Task { await presenter.saveAction() } }
                        .fontWeight(.semibold)
                        .foregroundStyle(viewModel.canSave ? HearthColor.pine : HearthColor.mute)
                        .disabled(!viewModel.canSave)
                }
            }
        }
        .tint(HearthColor.pine)
        .confirmationDialog(Strings.deleteProjectQuestion, isPresented: $viewModel.isConfirmingDelete, titleVisibility: .visible) {
            Button(Strings.deleteProject, role: .destructive) {
                Haptics.play(.warning)
                Task { await presenter.deleteAction() }
            }
            Button(Strings.cancel, role: .cancel) {}
        }
        .alert(Strings.filesUnreadable, isPresented: $viewModel.isShowingUnreadableFiles) {
            Button(Strings.ok, role: .cancel) {}
        }
        .alert(Strings.projectSaveFailed, isPresented: $viewModel.isShowingSaveFailure) {
            Button(Strings.ok, role: .cancel) {}
        }
        .fileImporter(isPresented: $isFileImporterPresented, allowedContentTypes: [.pdf, .text], allowsMultipleSelection: true) { result in
            // Cancelling the picker reports a failure; there is nothing to add either way.
            let urls = (try? result.get()) ?? []
            Task {
                let documents = await DocumentLoader.documents(from: urls)
                presenter.addDocumentsAction(documents, unreadableCount: urls.count - documents.count)
            }
        }
    }

    // MARK: Reference files

    /// The files, each of which can be swiped away or removed with its button, and the button that adds more.
    private func filesSection(documents: [AttachedDocument]) -> some View {
        Section {
            ForEach(documents) { document in
                fileRow(document)
            }
            Text(Strings.projectNoFiles)
                .foregroundStyle(HearthColor.mute)
                .opacity(documents.isEmpty ? 1 : 0)
                .frame(height: documents.isEmpty ? nil : 0)
                .accessibilityHidden(!documents.isEmpty)
                .listRowSeparator(.hidden)
            Button(action: { isFileImporterPresented = true }, label: {
                Label(Strings.projectAddFiles, systemImage: "plus")
                    .foregroundStyle(HearthColor.pine)
            })
        } header: {
            Text(Strings.projectFiles)
        } footer: {
            Text(Strings.projectFilesFooter)
        }
    }

    private func fileRow(_ document: AttachedDocument) -> some View {
        HStack(spacing: HearthSpacing.s10) {
            Image(systemName: "doc.text")
                .font(.body)
                .foregroundStyle(HearthColor.pine)
                .accessibilityHidden(true)
            Text(document.name)
                .font(.body)
                .foregroundStyle(HearthColor.ink)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: { presenter.removeDocumentAction(document.id) }, label: {
                Image(systemName: "xmark")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(HearthColor.mute)
                    .frame(width: Self.removeButtonSide, height: Self.removeButtonSide)
                    .contentShape(Rectangle())
            })
            // Without this the whole row would be the button, as a form makes of a row with one button in it.
            .buttonStyle(.borderless)
            .accessibilityLabel(Strings.removeFile)
        }
        .swipeActions {
            Button(Strings.delete, role: .destructive) { presenter.removeDocumentAction(document.id) }
        }
    }
}
