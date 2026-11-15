import Foundation
import HearthCore
import HearthDomain
import os

/// What the project picker tells the coordinator: that it should close, and what was chosen.
@MainActor
protocol ProjectPickerPresenterDelegate: AnyObject {
    /// The chat now belongs to the given project, or to none.
    func projectPickerPresenter(_ presenter: ProjectPickerPresenter, didMove id: Conversation.ID, to projectID: Project.ID?)
    /// A new project is wanted for the chat to go in.
    func projectPickerPresenter(_ presenter: ProjectPickerPresenter, didRequestNewProjectFor id: Conversation.ID)
    func projectPickerPresenterDidCancel(_ presenter: ProjectPickerPresenter)
}

/// Chooses a project for one chat: any of the saved projects, a new one, or none at all.
@MainActor
final class ProjectPickerPresenter {
    let viewModel = ProjectPickerViewModel()
    weak var delegate: (any ProjectPickerPresenterDelegate)?

    private let projectStore: ProjectStore
    private let conversationStore: ConversationStore
    private let logger = Logger(for: ProjectPickerPresenter.self)

    init(projectStore: ProjectStore, conversationStore: ConversationStore) {
        self.projectStore = projectStore
        self.conversationStore = conversationStore
    }

    // MARK: What the picker shows

    /// The projects to choose from, most recently changed first.
    var projects: [ProjectRowViewConfiguration] {
        projectStore.projects.map { ProjectRowViewConfiguration(id: $0.id, name: $0.name) }
    }

    /// Whether the chat is in a project already, in which case it is being moved and can also be taken out.
    var isMoving: Bool { viewModel.currentProjectID != nil }

    // MARK: Opening

    /// Readies the picker for a chat before the sheet opens.
    ///
    /// - Parameter unsavedProjectID: The project of a chat that has not been saved yet, which the store cannot
    ///   answer for. A saved chat's project is read from the store, and one that has since been deleted counts as none.
    func begin(for conversationID: Conversation.ID, unsavedProjectID: Project.ID? = nil) {
        let stored = conversationStore.conversation(for: conversationID)
        viewModel.conversationID = conversationID
        viewModel.currentProjectID = projectStore.project(for: stored == nil ? unsavedProjectID : stored?.projectID)?.id
        viewModel.isShowingSaveFailure = false
    }

    // MARK: Choosing

    /// Puts the chat in the chosen project, or with `nil` takes it out of the one it is in.
    ///
    /// A chat that has not been saved yet is not in the store, which then has nothing to change; the coordinator
    /// passes the choice on to the open chat, which carries it until its first save.
    func chooseAction(_ projectID: Project.ID?) async {
        guard let conversationID = viewModel.conversationID else {
            return
        }
        do {
            try await conversationStore.setProject(projectID, for: conversationID)
            delegate?.projectPickerPresenter(self, didMove: conversationID, to: projectID)
        } catch {
            logger.error("Moving a conversation to a project failed: \(error.localizedDescription, privacy: .public)")
            viewModel.isShowingSaveFailure = true
        }
    }

    func newProjectAction() {
        guard let conversationID = viewModel.conversationID else {
            return
        }
        delegate?.projectPickerPresenter(self, didRequestNewProjectFor: conversationID)
    }

    func closeAction() {
        delegate?.projectPickerPresenterDidCancel(self)
    }
}
