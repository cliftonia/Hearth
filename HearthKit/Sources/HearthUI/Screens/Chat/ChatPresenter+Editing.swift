import Foundation
import HearthDomain

// Attaching files, and editing a message that was already sent.
extension ChatPresenter {
    /// Attaches the files that could be read, and says so if some could not.
    func addDocumentsAction(_ documents: [AttachedDocument], unreadableCount: Int) {
        viewModel.pendingDocuments.append(contentsOf: documents)
        if unreadableCount > 0 {
            viewModel.error = ErrorViewConfiguration(title: Strings.attach, message: Strings.filesUnreadable, retryActionLabel: nil)
        }
    }

    /// Puts what was shared from another app into the message being written.
    func receiveSharedAction(_ shared: SharedContent) {
        viewModel.draft = [viewModel.draft, shared.text].filter { !$0.isEmpty }.joined(separator: "\n")
        addImagesAction(shared.imagesJPEG)
        addDocumentsAction(shared.documents, unreadableCount: shared.unreadableCount)
    }

    func removeDocumentAction(_ id: AttachedDocument.ID) {
        viewModel.pendingDocuments.removeAll { $0.id == id }
    }

    /// Puts a sent message back in the composer. Sending it replaces that message and everything after it.
    func editAction(_ id: Message.ID) {
        guard !viewModel.isStreaming, let message = viewModel.conversation.messages.first(where: { $0.id == id }), message.role == .user else {
            return
        }
        viewModel.editingMessageID = id
        viewModel.draft = message.text
        viewModel.pendingImagesJPEG = message.imagesJPEG
        viewModel.pendingDocuments = message.documents
    }

    /// Leaves the sent message as it was and empties the composer.
    func cancelEditAction() {
        viewModel.editingMessageID = nil
        viewModel.draft = ""
        viewModel.pendingImagesJPEG = []
        viewModel.pendingDocuments = []
    }

    /// Drops the message being edited, and the replies that followed it, ahead of the edited one being sent.
    func discardEditedMessages() {
        guard let id = viewModel.editingMessageID else {
            return
        }
        viewModel.editingMessageID = nil
        let messages = viewModel.conversation.messages
        guard let index = messages.firstIndex(where: { $0.id == id }) else {
            return
        }
        viewModel.conversation = viewModel.conversation.updating(messages: Array(messages[..<index]))
    }

    /// Keeps the open conversation in step when it is renamed from the drawer.
    func conversationWasRenamed(_ id: Conversation.ID, to title: String) {
        guard viewModel.conversation.id == id else {
            return
        }
        viewModel.conversation = viewModel.conversation.updating(title: title)
    }
}
