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

    public func load() async throws {
        conversations = try await provider.loadAll().sorted { $0.updatedAt > $1.updatedAt }
    }

    public func conversation(for id: Conversation.ID) -> Conversation? {
        conversations.first { $0.id == id }
    }

    /// Puts the conversation at the top of the list and writes it to disk.
    ///
    /// Whether it is pinned is the store's to decide, so a copy edited elsewhere cannot undo a pin.
    public func save(_ conversation: Conversation) async throws {
        let saved = conversation.updating(isPinned: self.conversation(for: conversation.id)?.isPinned)
        conversations.removeAll { $0.id == saved.id }
        conversations.insert(saved, at: 0)
        try await provider.save(saved)
    }

    /// Pins or unpins a conversation without counting it as activity: its place by date is unchanged.
    public func setPinned(_ isPinned: Bool, for id: Conversation.ID) async throws {
        try await replace(id) { $0.updating(isPinned: isPinned) }
    }

    /// Gives a conversation a new title, leaving its place by date unchanged.
    public func rename(_ id: Conversation.ID, to title: String) async throws {
        try await replace(id) { $0.updating(title: title) }
    }

    private func replace(_ id: Conversation.ID, with change: (Conversation) -> Conversation) async throws {
        guard let index = conversations.firstIndex(where: { $0.id == id }) else {
            return
        }
        let changed = change(conversations[index])
        conversations[index] = changed
        try await provider.save(changed)
    }

    public func delete(_ id: Conversation.ID) async throws {
        conversations.removeAll { $0.id == id }
        try await provider.delete(id)
    }
}
