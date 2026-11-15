import Foundation

// Changes that arrive from another device. They are written as they came, stamps included, and sync is not told
// of them, since they are already on the hub.
public extension ConversationStore {
    /// Puts a conversation from another device in the list, in its place by date, replacing any copy held.
    /// A private chat of this device is never replaced.
    func applyRemote(_ conversation: Conversation) async throws {
        if self.conversation(for: conversation.id)?.isPrivate == true {
            return
        }
        try await provider.save(conversation)
        // The list may have changed while the file was written, so the old copy is found again by its identifier.
        var list = conversations.filter { $0.id != conversation.id }
        list.insert(conversation, at: list.firstIndex { $0.updatedAt < conversation.updatedAt } ?? list.count)
        replaceAll(with: list)
    }

    /// Removes a conversation another device deleted. One not held, or a private one, is left alone.
    func deleteRemote(_ id: Conversation.ID) async throws {
        guard let conversation = conversation(for: id), !conversation.isPrivate else {
            return
        }
        try await provider.delete(id)
        replaceAll(with: conversations.filter { $0.id != id })
    }

    /// Takes every conversation out of a project another device deleted, without counting it as a change here:
    /// the device that deleted the project sends its own changes to those chats.
    func releaseRemote(from projectID: Project.ID) async throws {
        for conversation in conversations where conversation.projectID == projectID {
            let released = conversation.updating(project: .noProject)
            try await provider.save(released)
            replaceAll(with: conversations.map { $0.id == released.id ? released : $0 })
        }
    }
}
