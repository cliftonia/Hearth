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
    public func save(_ conversation: Conversation) async throws {
        conversations.removeAll { $0.id == conversation.id }
        conversations.insert(conversation, at: 0)
        try await provider.save(conversation)
    }

    public func delete(_ id: Conversation.ID) async throws {
        conversations.removeAll { $0.id == id }
        try await provider.delete(id)
    }
}
