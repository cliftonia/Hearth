import Foundation

/// Carries out what changes a project and its chats together.
public final class ProjectInteractor: Sendable {
    private let projectStore: ProjectStore
    private let conversationStore: ConversationStore

    public init(projectStore: ProjectStore, conversationStore: ConversationStore) {
        self.projectStore = projectStore
        self.conversationStore = conversationStore
    }

    /// Deletes a project and keeps its chats, which simply stop belonging to it.
    ///
    /// The chats are let go first. Should that fail part of the way the project is still there, holding the chats
    /// that could not be changed, and the error is passed on; no chat is ever left pointing at a project that is gone.
    @MainActor
    public func delete(_ id: Project.ID) async throws {
        try await conversationStore.removeAll(from: id)
        try await projectStore.delete(id)
    }
}
