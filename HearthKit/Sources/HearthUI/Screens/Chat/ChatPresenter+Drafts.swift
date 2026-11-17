import Foundation
import HearthDomain

/// What was being written in a chat: the words and what was attached to them.
struct ComposerDraft: Equatable {
    let text: String
    let imagesJPEG: [Data]
    let documents: [AttachedDocument]

    var isEmpty: Bool {
        text.isEmpty && imagesJPEG.isEmpty && documents.isEmpty
    }
}

// Each chat keeps its own draft, so what is being written in one never follows the user into another.
extension ChatPresenter {
    /// Puts aside what is being written in the open chat, to be given back when it is opened again. A sent message
    /// being edited is not a draft, and is let go as before.
    func keepDraftOfOpenChat() {
        let id = viewModel.conversation.id
        guard viewModel.editingMessageID == nil else {
            composerDrafts[id] = nil
            return
        }
        let draft = ComposerDraft(text: viewModel.draft, imagesJPEG: viewModel.pendingImagesJPEG, documents: viewModel.pendingDocuments)
        composerDrafts[id] = draft.isEmpty ? nil : draft
    }

    /// Fills the composer with what was being written in the given chat when it was left, if anything was.
    func restoreDraft(of id: Conversation.ID) {
        guard let draft = composerDrafts.removeValue(forKey: id) else {
            return
        }
        viewModel.draft = draft.text
        viewModel.pendingImagesJPEG = draft.imagesJPEG
        viewModel.pendingDocuments = draft.documents
    }
}
