import Foundation
import HearthDomain
@testable import HearthUI
import SwiftUI
import Testing

/// The chat's menu offers what the chat list's does.
@MainActor
struct ChatMenuTests {
    private static let project = Project(name: "Garden")
    private static let filed = Conversation(
        title: "Tomatoes",
        messages: [Message(role: .user, text: "When to plant tomatoes?")],
        projectID: project.id
    )

    @Test func `removing the open chat from its project files it in none`() async throws {
        let store = PresenterFixtures.conversationStore([Self.filed])
        try await store.load()
        let subject = PresenterFixtures.chatPresenter(conversationStore: store)
        await subject.selectConversationAction(Self.filed.id)

        await subject.removeFromProjectAction()

        #expect(store.conversation(for: Self.filed.id)?.projectID == nil)
        #expect(subject.viewModel.conversation.projectID == nil)
        #expect(subject.viewModel.error == nil)
    }
}
