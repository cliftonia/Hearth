import Foundation
import HearthDomain

// What the menu at the top of the chat does to the open conversation.
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
            viewModel.error = ErrorViewConfiguration(message: Strings.errorChangeFailed, retryActionLabel: nil)
        }
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
            viewModel.error = ErrorViewConfiguration(message: Strings.errorChangeFailed, retryActionLabel: nil)
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

    /// Keeps the open copy in step when the chat was filed elsewhere: by the picker or by a new project made for it.
    /// A chat not yet saved carries the choice here until its first save.
    func conversationWasMoved(_ id: Conversation.ID, to projectID: Project.ID?) {
        guard viewModel.conversation.id == id else {
            return
        }
        viewModel.conversation = viewModel.conversation.updating(project: ProjectMembership(projectID))
    }

    /// Deletes the open chat and starts a new one in its place.
    func deleteChatAction() async {
        let id = viewModel.conversation.id
        await stopAction()
        do {
            try await dependencies.conversationStore.delete(id)
            await newChatAction()
        } catch {
            logger.error("Deleting the chat failed: \(error.localizedDescription, privacy: .public)")
            viewModel.error = ErrorViewConfiguration(message: Strings.errorChangeFailed, retryActionLabel: nil)
        }
    }
}
