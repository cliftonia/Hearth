import Foundation
import HearthCore
import HearthDomain
import os

/// How the project sheet came to close.
enum ProjectOutcomeKind: Hashable {
    /// Closed with nothing kept.
    case cancelled
    /// A new project was made. `adopted` is the chat that was waiting to be put in it, if one was.
    case created(Project.ID, adopted: Conversation.ID?)
    case updated(Project.ID)
    case deleted(Project.ID)
}

/// What the project sheet tells the coordinator: that it should close, and what became of the project.
@MainActor
protocol ProjectPresenterDelegate: AnyObject {
    func projectPresenter(_ presenter: ProjectPresenter, didFinishWith outcome: ProjectOutcomeKind)
}

/// Makes a project or edits one: a draft of its name, instructions and reference files, kept only when the user
/// taps Done.
@MainActor
final class ProjectPresenter {
    let viewModel = ProjectViewModel()
    weak var delegate: (any ProjectPresenterDelegate)?

    private let projectStore: ProjectStore
    private let conversationStore: ConversationStore
    private let interactor: ProjectInteractor
    private let logger = Logger(for: ProjectPresenter.self)
    /// A chat waiting to be put in the project being made, as when "New project…" was chosen for it.
    private var adoptingID: Conversation.ID?

    init(projectStore: ProjectStore, conversationStore: ConversationStore, interactor: ProjectInteractor) {
        self.projectStore = projectStore
        self.conversationStore = conversationStore
        self.interactor = interactor
    }

    // MARK: Opening

    /// Fills the draft before the sheet opens: from the given project, or empty for a new one.
    ///
    /// - Parameter adopting: A chat to put in the project once it has been made. Ignored when editing.
    func begin(editing id: Project.ID? = nil, adopting conversationID: Conversation.ID? = nil) {
        let project = projectStore.project(for: id)
        viewModel.editingID = project?.id
        viewModel.name = project?.name ?? ""
        viewModel.instructions = project?.instructions ?? ""
        viewModel.documents = project?.documents ?? []
        viewModel.isConfirmingDelete = false
        viewModel.isShowingUnreadableFiles = false
        viewModel.isShowingSaveFailure = false
        adoptingID = project == nil ? conversationID : nil
    }

    // MARK: Reference files

    /// Adds the files that were picked, and says so if some of them could not be read.
    func addDocumentsAction(_ documents: [AttachedDocument], unreadableCount: Int) {
        viewModel.documents.append(contentsOf: documents)
        viewModel.isShowingUnreadableFiles = unreadableCount > 0
    }

    func removeDocumentAction(_ id: AttachedDocument.ID) {
        viewModel.documents.removeAll { $0.id == id }
    }

    // MARK: Closing

    func cancelAction() {
        delegate?.projectPresenter(self, didFinishWith: .cancelled)
    }

    /// Keeps the draft: as a new project, or over the one being edited. A project without a name is not kept.
    func saveAction() async {
        guard viewModel.canSave else {
            return
        }
        let name = viewModel.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let instructions = viewModel.instructions.trimmingCharacters(in: .whitespacesAndNewlines)
        let existing = projectStore.project(for: viewModel.editingID)
        let project = existing?.updating(name: name, instructions: instructions, documents: viewModel.documents, updatedAt: Date())
            ?? Project(name: name, instructions: instructions, documents: viewModel.documents)
        do {
            try await projectStore.save(project)
        } catch {
            logger.error("Saving a project failed: \(error.localizedDescription, privacy: .public)")
            viewModel.isShowingSaveFailure = true
            return
        }
        guard existing == nil else {
            delegate?.projectPresenter(self, didFinishWith: .updated(project.id))
            return
        }
        delegate?.projectPresenter(self, didFinishWith: .created(project.id, adopted: await adopt(into: project.id)))
    }

    /// Deletes the project being edited. Its chats are kept and stop belonging to it.
    func deleteAction() async {
        guard let id = viewModel.editingID else {
            return
        }
        do {
            try await interactor.delete(id)
            delegate?.projectPresenter(self, didFinishWith: .deleted(id))
        } catch {
            logger.error("Deleting a project failed: \(error.localizedDescription, privacy: .public)")
            viewModel.isShowingSaveFailure = true
        }
    }

    /// Puts the waiting chat, if there is one, in the project that has just been made, and returns its identifier.
    ///
    /// The project is already saved by now, so a chat that cannot be moved is only logged: the project stands, and
    /// the chat can be added to it again.
    private func adopt(into projectID: Project.ID) async -> Conversation.ID? {
        guard let adoptingID else {
            return nil
        }
        self.adoptingID = nil
        do {
            try await conversationStore.setProject(projectID, for: adoptingID)
            return adoptingID
        } catch {
            logger.error("Adding a conversation to a new project failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
