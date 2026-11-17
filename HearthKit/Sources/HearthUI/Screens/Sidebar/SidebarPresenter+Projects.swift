import Foundation
import HearthDomain

// The projects above the chat list, and filing a chat in one.
extension SidebarPresenter {
    /// The projects to list: all of them, or while searching those whose name matches.
    var projects: [ProjectRowViewConfiguration] {
        ConversationGrouper().projects(from: projectStore.projects, query: viewModel.query)
    }

    /// The project whose chats alone are listed. `nil` when every chat is listed, and when the project that was
    /// being looked at has since been deleted.
    var selectedProject: ProjectRowViewConfiguration? {
        projectStore.project(for: viewModel.selectedProjectID).map { ProjectRowViewConfiguration(id: $0.id, name: $0.name) }
    }

    /// Narrows the list to one project's chats.
    func selectProjectAction(_ id: Project.ID) {
        viewModel.selectedProjectID = id
    }

    /// Goes back from a project's chats to every chat.
    func allChatsAction() {
        viewModel.selectedProjectID = nil
    }

    /// A project has been deleted: if its chats were being looked at, the list goes back to every chat, where
    /// they now are.
    func projectWasDeleted(_ id: Project.ID) {
        if viewModel.selectedProjectID == id {
            viewModel.selectedProjectID = nil
        }
    }

    /// Opens the settings of the project being looked at.
    func projectSettingsAction() {
        guard let id = selectedProject?.id else {
            return
        }
        delegate?.sidebarPresenter(self, didRequestEditing: id)
    }

    /// Asks which project a chat should go in.
    func addToProjectAction(_ row: SidebarRowViewConfiguration) {
        delegate?.sidebarPresenter(self, didRequestProjectFor: row.id)
    }

    /// Takes a chat out of its project. The chat itself is kept.
    func removeFromProjectAction(_ row: SidebarRowViewConfiguration) async {
        do {
            try await conversationStore.setProject(nil, for: row.id)
        } catch {
            logger.error("Removing a conversation from its project failed: \(error.localizedDescription, privacy: .public)")
            viewModel.isShowingSaveFailure = true
        }
    }
}
