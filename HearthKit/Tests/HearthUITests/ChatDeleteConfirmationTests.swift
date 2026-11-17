import Foundation
import HearthDomain
@testable import HearthUI
import Testing

/// Deleting a chat, from its menu, the chat list or the keyboard, is asked about first, and says when it reaches
/// every synced device.
@MainActor
struct ChatDeleteConfirmationTests {
    private static let saved = Conversation(title: "Garden", messages: [Message(role: .user, text: "When to plant tomatoes?")])

    /// A store holding one saved chat, and a record of what it was asked to delete.
    @MainActor
    final class Fixture {
        let deleted = DeletedIDs<Conversation.ID>()
        let store: ConversationStore

        init(conversations: [Conversation] = [ChatDeleteConfirmationTests.saved]) {
            let deleted = deleted
            store = ConversationStore(provider: ConversationDataProvider(
                loadAll: { conversations },
                save: { _ in },
                delete: { deleted.record($0) },
                deleteAll: {}
            ))
        }

        func makeChatPresenter(isSyncOn: Bool = false) async -> ChatPresenter {
            try? await store.load()
            return PresenterFixtures.chatPresenter(conversationStore: store, isSyncOn: { isSyncOn })
        }

        func makeSidebarPresenter(isSyncOn: Bool = false) async -> SidebarPresenter {
            try? await store.load()
            let subject = SidebarPresenter(
                conversationStore: store,
                projectStore: PresenterFixtures.projectStore(),
                modelStore: ModelStore(fetchModels: { _ in [] }),
                settingsStore: PresenterFixtures.settingsStore(),
                selectedConversationID: { ChatDeleteConfirmationTests.saved.id }
            )
            subject.isSyncOn = { isSyncOn }
            return subject
        }
    }

    // MARK: The chat's menu

    @Test func `asking to delete the open chat only asks`() async {
        let fixture = Fixture()
        let subject = await fixture.makeChatPresenter()
        await subject.selectConversationAction(Self.saved.id)

        subject.requestDeleteChatAction()

        #expect(subject.viewModel.isConfirmingDeleteChat)
        #expect(fixture.deleted.all.isEmpty)
    }

    @Test func `a chat that has not begun is not offered for deleting`() async {
        let subject = await Fixture().makeChatPresenter()

        subject.requestDeleteChatAction()

        #expect(!subject.canDeleteChat)
        #expect(!subject.viewModel.isConfirmingDeleteChat)
    }

    @Test func `confirming deletes the open chat and starts a new one`() async {
        let fixture = Fixture()
        let subject = await fixture.makeChatPresenter()
        await subject.selectConversationAction(Self.saved.id)
        subject.requestDeleteChatAction()

        await subject.deleteChatAction()

        #expect(fixture.deleted.all == [Self.saved.id])
        #expect(!subject.viewModel.isConfirmingDeleteChat)
        #expect(subject.viewModel.conversation.id != Self.saved.id)
        #expect(subject.viewModel.conversation.messages.isEmpty)
    }

    @Test(arguments: [
        (isSyncOn: true, isPrivate: false, mentionsDevices: true),
        (isSyncOn: false, isPrivate: false, mentionsDevices: false),
        (isSyncOn: true, isPrivate: true, mentionsDevices: false)
    ])
    func `the question says the chat leaves every device only when it is synced`(
        _ example: (isSyncOn: Bool, isPrivate: Bool, mentionsDevices: Bool)
    ) async {
        let conversation = Conversation(title: "Notes", messages: [Message(role: .user, text: "Hello")], isPrivate: example.isPrivate)
        let fixture = Fixture(conversations: [conversation])
        let chat = await fixture.makeChatPresenter(isSyncOn: example.isSyncOn)
        await chat.selectConversationAction(conversation.id)
        let sidebar = await fixture.makeSidebarPresenter(isSyncOn: example.isSyncOn)
        var expected = Strings.deleteChatDetail
        if example.mentionsDevices {
            expected = Strings.deleteChatSyncedDetail
        }

        #expect(chat.deleteChatDetail == expected)
        #expect(sidebar.deleteDetail(for: conversation.id) == expected)
    }

    // MARK: The chat list

    @Test func `asking to delete from the chat list only asks`() async {
        let fixture = Fixture()
        let subject = await fixture.makeSidebarPresenter()

        subject.requestDeleteAction(Self.saved.id)

        #expect(subject.viewModel.isConfirmingDelete)
        #expect(subject.viewModel.deletingID == Self.saved.id)
        #expect(fixture.deleted.all.isEmpty)
    }

    @Test func `cancelling the question from the chat list deletes nothing`() async {
        let fixture = Fixture()
        let subject = await fixture.makeSidebarPresenter()
        subject.requestDeleteAction(Self.saved.id)

        subject.viewModel.isConfirmingDelete = false

        #expect(subject.viewModel.deletingID == nil)
        #expect(fixture.deleted.all.isEmpty)
    }

    @Test func `confirming from the chat list deletes the chat that was asked about`() async {
        let fixture = Fixture()
        let subject = await fixture.makeSidebarPresenter()
        subject.requestDeleteAction(Self.saved.id)

        await subject.confirmDeleteAction(Self.saved.id)

        #expect(fixture.deleted.all == [Self.saved.id])
        #expect(subject.viewModel.deletingID == nil)
    }
}
