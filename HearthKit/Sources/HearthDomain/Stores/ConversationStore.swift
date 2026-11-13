import Foundation
import Observation

/// Every saved conversation, newest first, shared by the chat and the sidebar.
@MainActor
@Observable
public final class ConversationStore {
    public private(set) var conversations: [Conversation] = []

    private let provider: ConversationDataProvider

    public init(provider: ConversationDataProvider) {
        self.provider = provider
    }

    /// Reads every conversation from disk, most recently active first.
    public func load() async throws {
        conversations = try await provider.loadAll().sorted { $0.updatedAt > $1.updatedAt }
    }

    public func conversation(for id: Conversation.ID) -> Conversation? {
        conversations.first { $0.id == id }
    }

    /// Puts the conversation at the top of the list and writes it to disk.
    ///
    /// Whether it is pinned is the store's to decide, so a copy edited elsewhere cannot undo a pin.
    /// If the write fails the list goes back to what is on disk, and the error is passed on.
    public func save(_ conversation: Conversation) async throws {
        let previousIndex = conversations.firstIndex { $0.id == conversation.id }
        let previous = previousIndex.map { conversations[$0] }
        let saved = conversation.updating(isPinned: previous?.isPinned)
        conversations.removeAll { $0.id == saved.id }
        conversations.insert(saved, at: 0)
        do {
            try await provider.save(saved)
        } catch {
            conversations.removeAll { $0.id == saved.id }
            if let previous, let previousIndex {
                conversations.insert(previous, at: min(previousIndex, conversations.count))
            }
            throw error
        }
    }

    /// Pins or unpins a conversation without counting it as activity: its place by date is unchanged.
    public func setPinned(_ isPinned: Bool, for id: Conversation.ID) async throws {
        try await replace(id) { $0.updating(isPinned: isPinned) }
    }

    /// Gives a conversation a new title, leaving its place by date unchanged.
    public func rename(_ id: Conversation.ID, to title: String) async throws {
        try await replace(id) { $0.updating(title: title) }
    }

    /// Changes one conversation where it stands and writes it to disk. An unknown identifier is ignored.
    /// If the write fails the conversation goes back to how it was, and the error is passed on.
    private func replace(_ id: Conversation.ID, with change: (Conversation) -> Conversation) async throws {
        guard let index = conversations.firstIndex(where: { $0.id == id }) else {
            return
        }
        let previous = conversations[index]
        let changed = change(previous)
        conversations[index] = changed
        do {
            try await provider.save(changed)
        } catch {
            if let current = conversations.firstIndex(where: { $0.id == id }) {
                conversations[current] = previous
            }
            throw error
        }
    }

    /// Removes a conversation from the list and from disk. If it cannot be removed from disk it stays in the list.
    public func delete(_ id: Conversation.ID) async throws {
        guard let index = conversations.firstIndex(where: { $0.id == id }) else {
            try await provider.delete(id)
            return
        }
        let removed = conversations.remove(at: index)
        do {
            try await provider.delete(id)
        } catch {
            conversations.insert(removed, at: min(index, conversations.count))
            throw error
        }
    }
}
