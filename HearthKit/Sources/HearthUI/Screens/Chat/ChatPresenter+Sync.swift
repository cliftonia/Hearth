import Foundation
import HearthDomain

// What sync needs of the open chat: whether it is being written to, and taking in another device's changes to it.
extension ChatPresenter {
    /// Whether the chat with this identifier is the open one and a reply, a picture or a report is streaming into
    /// it. Sync neither replaces nor sends such a chat until it is finished.
    func isWriting(_ id: Conversation.ID) -> Bool {
        viewModel.isStreaming && viewModel.conversation.id == id
    }

    /// Another device changed or deleted some chats. If the open chat is among them it shows the new copy, or, if
    /// it was deleted, a new chat takes its place, as when it is deleted from the list here.
    func conversationsChangedRemotely(_ ids: Set<Conversation.ID>) async {
        let open = viewModel.conversation.id
        guard ids.contains(open), !isWriting(open) else {
            return
        }
        if let stored = dependencies.conversationStore.conversation(for: open) {
            viewModel.conversation = stored
        } else {
            await newChatAction()
        }
    }
}
