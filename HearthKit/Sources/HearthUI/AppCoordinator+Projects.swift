import HearthDomain

// Where the project sheets lead: making and editing a project, and filing a chat in one.
extension AppCoordinator {
    /// Opens the sheet that chooses a project for a chat, whether it was asked for from the chat list or from the
    /// open chat's menu.
    func presentProjectPicker(for id: Conversation.ID) {
        // The open chat may not have been saved yet, in which case only its own copy knows its project.
        let open = chatPresenter.viewModel.conversation
        projectPickerPresenter.begin(for: id, unsavedProjectID: open.id == id ? open.projectID : nil)
        router.projectSheet = .picker
    }
}

// MARK: - ProjectPickerPresenterDelegate

extension AppCoordinator: ProjectPickerPresenterDelegate {
    func projectPickerPresenter(_ presenter: ProjectPickerPresenter, didMove id: Conversation.ID, to projectID: Project.ID?) {
        chatPresenter.conversationWasMoved(id, to: projectID)
        router.projectSheet = nil
    }

    /// The picker gives way to the sheet that makes a project, which puts the chat in it once it is made.
    func projectPickerPresenter(_ presenter: ProjectPickerPresenter, didRequestNewProjectFor id: Conversation.ID) {
        projectPresenter.begin(adopting: id)
        router.projectSheet = .editor
    }

    func projectPickerPresenterDidCancel(_ presenter: ProjectPickerPresenter) {
        router.projectSheet = nil
    }
}

// MARK: - ProjectPresenterDelegate

extension AppCoordinator: ProjectPresenterDelegate {
    func projectPresenter(_ presenter: ProjectPresenter, didFinishWith outcome: ProjectOutcomeKind) {
        router.projectSheet = nil
        switch outcome {
        case .cancelled, .updated:
            break
        case .created(let id, let adopted):
            if let adopted {
                // Made for a chat: the chat is told where it now belongs, and the list stays as it was.
                chatPresenter.conversationWasMoved(adopted, to: id)
            } else {
                // Made from the chat list: the list opens the new project, ready for its first chat.
                sidebarPresenter.selectProjectAction(id)
            }
        case .deleted(let id):
            // Its chats are back among all the others, so the list goes back to showing them all.
            sidebarPresenter.projectWasDeleted(id)
        }
    }
}
