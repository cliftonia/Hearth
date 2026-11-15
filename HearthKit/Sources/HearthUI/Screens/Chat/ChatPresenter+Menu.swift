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

    /// Saves the title typed into the rename alert. An empty title changes nothing.
    func commitRenameChatAction() async {
        let title = viewModel.chatTitleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let id = viewModel.conversation.id
        guard !title.isEmpty else {
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
