import Foundation
import HearthDomain
@testable import HearthUI
import Testing

/// What is being written stays with the chat it was written in: it does not follow the user into another chat, and
/// comes back when the first is opened again.
@MainActor
struct ComposerDraftTests {
    private static let garden = Conversation(title: "Garden", messages: [Message(role: .user, text: "Tomatoes?")])
    private static let travel = Conversation(title: "Travel", messages: [Message(role: .user, text: "Lisbon?")])

    private func makeTestSubject() async -> ChatPresenter {
        let store = PresenterFixtures.conversationStore([Self.garden, Self.travel])
        try? await store.load()
        let subject = PresenterFixtures.chatPresenter(conversationStore: store)
        await subject.selectConversationAction(Self.garden.id)
        return subject
    }

    @Test func `a draft does not follow the user into another chat`() async {
        let subject = await makeTestSubject()
        subject.viewModel.draft = "Half a thought"
        subject.addDocumentsAction([AttachedDocument(name: "seeds.txt", text: "Basil")], unreadableCount: 0)

        await subject.selectConversationAction(Self.travel.id)

        #expect(subject.viewModel.draft.isEmpty)
        #expect(subject.viewModel.pendingDocuments.isEmpty)
    }

    @Test func `a draft comes back when its chat is opened again`() async {
        let subject = await makeTestSubject()
        subject.viewModel.draft = "Half a thought"
        subject.addImagesAction([Data([1, 2, 3])])

        await subject.selectConversationAction(Self.travel.id)
        await subject.selectConversationAction(Self.garden.id)

        #expect(subject.viewModel.draft == "Half a thought")
        #expect(subject.viewModel.pendingImagesJPEG == [Data([1, 2, 3])])
    }

    @Test func `a new chat starts with an empty composer`() async {
        let subject = await makeTestSubject()
        subject.viewModel.draft = "Half a thought"

        await subject.newChatAction()

        #expect(subject.viewModel.draft.isEmpty)
    }

    @Test func `a sent message being edited is not kept as a draft`() async {
        let subject = await makeTestSubject()
        subject.editAction(Self.garden.messages[0].id)

        await subject.selectConversationAction(Self.travel.id)
        await subject.selectConversationAction(Self.garden.id)

        #expect(subject.viewModel.draft.isEmpty)
        #expect(subject.viewModel.editingMessageID == nil)
    }
}
