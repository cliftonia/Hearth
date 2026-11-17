import Foundation
import HearthDomain

// What the menu at the top of the chat does to the open conversation, and the + menu's scheduled task.
extension ChatPresenter {
    var isChatPinned: Bool {
        dependencies.conversationStore.conversation(for: viewModel.conversation.id)?.isPinned ?? false
    }

    /// The open conversation as Markdown, for sharing.
    var chatExportText: String {
        let exporter = ConversationExporter(userLabel: Strings.exportUser, assistantLabel: Strings.brand, untitled: Strings.newChat)
        return exporter.markdown(for: viewModel.conversation)
    }

    /// Pins the open chat to the top of the list, or lets it go back among the others.
    func togglePinAction() async {
        do {
            try await dependencies.conversationStore.setPinned(!isChatPinned, for: viewModel.conversation.id)
        } catch {
            logger.error("Pinning the chat failed: \(error.localizedDescription, privacy: .public)")
            showError(ErrorViewConfiguration(message: Strings.errorChangeFailed, retryActionLabel: nil))
        }
    }

    /// Asks for a scheduled task that asks what is being written. The composer keeps its text either way.
    func scheduleTaskAction() {
        delegate?.chatPresenter(self, didRequestTaskWith: viewModel.draft)
    }

    /// Asks for a new project, from the plus menu.
    func newProjectAction() {
        delegate?.chatPresenterDidRequestNewProject(self)
    }

    /// Opens the rename alert with the chat's present title in its field.
    func renameChatAction() {
        viewModel.chatTitleDraft = viewModel.conversation.title
        viewModel.isRenamingChat = true
    }

    /// Saves the title typed into the rename alert, as `Conversation.renamedTitle(from:)` has it. An empty title
    /// changes nothing.
    func commitRenameChatAction() async {
        let id = viewModel.conversation.id
        guard let title = Conversation.renamedTitle(from: viewModel.chatTitleDraft) else {
            return
        }
        do {
            try await dependencies.conversationStore.rename(id, to: title)
            conversationWasRenamed(id, to: title)
        } catch {
            logger.error("Renaming the chat failed: \(error.localizedDescription, privacy: .public)")
            showError(ErrorViewConfiguration(message: Strings.errorChangeFailed, retryActionLabel: nil))
        }
    }

    // MARK: Project

    /// The project the open chat belongs to; `nil` when it is in none, and when its project has been deleted.
    ///
    /// Once a chat has been saved the store says where it belongs, since the chat list can move it while it is
    /// open. Until then the open copy is all there is.
    var chatProject: Project? {
        let open = viewModel.conversation
        guard let stored = dependencies.conversationStore.conversation(for: open.id) else {
            return dependencies.projectStore.project(for: open.projectID)
        }
        return dependencies.projectStore.project(for: stored.projectID)
    }

    /// Asks which project the open chat should go in.
    func projectAction() {
        delegate?.chatPresenter(self, didRequestProjectFor: viewModel.conversation.id)
    }

    /// Takes the open chat out of its project, from the chat's menu, as the chat list's menu does.
    func removeFromProjectAction() async {
        let id = viewModel.conversation.id
        do {
            if dependencies.conversationStore.conversation(for: id) != nil {
                try await dependencies.conversationStore.setProject(nil, for: id)
            }
            conversationWasMoved(id, to: nil)
        } catch {
            logger.error("Removing the chat from its project failed: \(error.localizedDescription, privacy: .public)")
            showError(ErrorViewConfiguration(message: Strings.errorChangeFailed, retryActionLabel: nil))
        }
    }

    /// Keeps the open copy in step when the chat was filed elsewhere: by the picker or by a new project made for it.
    /// A chat not yet saved carries the choice here until its first save.
    func conversationWasMoved(_ id: Conversation.ID, to projectID: Project.ID?) {
        guard viewModel.conversation.id == id else {
            return
        }
        viewModel.conversation = viewModel.conversation.updating(project: ProjectMembership(projectID))
    }

    // MARK: Deleting

    /// Whether the open chat can be deleted: it has begun, and so is saved.
    var canDeleteChat: Bool {
        !viewModel.conversation.messages.isEmpty
    }

    /// What the delete confirmation says beneath its question: that the chat goes from every device when it is synced,
    /// which a private chat never is.
    var deleteChatDetail: String {
        dependencies.isSyncOn() && !viewModel.conversation.isPrivate ? Strings.deleteChatSyncedDetail : Strings.deleteChatDetail
    }

    /// Asks whether to delete the open chat, from its menu or the keyboard. Nothing is deleted until the answer.
    func requestDeleteChatAction() {
        guard canDeleteChat else {
            return
        }
        viewModel.isConfirmingDeleteChat = true
    }

    /// Deletes the open chat and starts a new one in its place, once the user has confirmed.
    func deleteChatAction() async {
        viewModel.isConfirmingDeleteChat = false
        let id = viewModel.conversation.id
        await stopAction()
        do {
            try await dependencies.conversationStore.delete(id)
            await newChatAction()
            composerDrafts[id] = nil
        } catch {
            logger.error("Deleting the chat failed: \(error.localizedDescription, privacy: .public)")
            showError(ErrorViewConfiguration(message: Strings.errorChangeFailed, retryActionLabel: nil))
        }
    }
}
