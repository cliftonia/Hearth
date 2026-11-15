import Foundation
import HearthDomain
@testable import HearthUI
import Testing

/// When the chat announces a finished reply, in what words, and how the greeting finds the user's name.
@MainActor
struct ChatNotificationTests {
    /// The chat presenter with the notifications it posts, and whether the app is in front of the user.
    @MainActor
    final class Fixture {
        var isOnScreen = false
        let notifications = NotificationsFixture(permission: .allowed)
        let settingsStore: SettingsStore
        let conversationStore: ConversationStore

        init(settings: ServerSettings = ServerSettings(isReplyNotificationsEnabled: true), stored: [Conversation] = []) {
            settingsStore = PresenterFixtures.settingsStore(settings)
            conversationStore = PresenterFixtures.conversationStore(stored)
        }

        func makeTestSubject() -> ChatPresenter {
            ChatPresenter(dependencies: ChatPresenter.Dependencies(
                chat: PresenterFixtures.chat,
                speech: PresenterFixtures.speech,
                image: PresenterFixtures.image,
                dictation: PresenterFixtures.dictation,
                notifications: notifications.provider,
                settingsStore: settingsStore,
                modelStore: ModelStore(fetchModels: { _ in [] }),
                conversationStore: conversationStore,
                memoryStore: PresenterFixtures.memoryStore(),
                projectStore: PresenterFixtures.projectStore(),
                isLocked: { false },
                isOnScreen: { self.isOnScreen }
            ))
        }
    }

    private let reply = Message(role: .assistant, text: "Paris is the capital of France.")

    private func conversation(isPrivate: Bool = false, reply: Message) -> Conversation {
        Conversation(title: "France", messages: [Message(role: .user, text: "Capital of France?"), reply], isPrivate: isPrivate)
    }

    @Test func `a reply that finishes off screen is announced under the chat's title, and a tap leads back to it`() async {
        let fixture = Fixture()
        let subject = fixture.makeTestSubject()
        subject.viewModel.conversation = conversation(reply: reply)

        await subject.notifyReplyFinished(reply.id)

        let expected = ReplyNotification(conversationID: subject.viewModel.conversation.id, title: "France", body: "Paris is the capital of France.")
        #expect(fixture.notifications.posted == [expected])
    }

    @Test func `nothing is announced while the chat is on screen`() async {
        let fixture = Fixture()
        fixture.isOnScreen = true
        let subject = fixture.makeTestSubject()
        subject.viewModel.conversation = conversation(reply: reply)

        await subject.notifyReplyFinished(reply.id)

        #expect(fixture.notifications.posted.isEmpty)
    }

    @Test func `nothing is announced with the switch off, or for a turn that failed`() async {
        let off = Fixture(settings: ServerSettings())
        let quiet = off.makeTestSubject()
        quiet.viewModel.conversation = conversation(reply: reply)
        await quiet.notifyReplyFinished(reply.id)
        #expect(off.notifications.posted.isEmpty)

        let fixture = Fixture()
        let failed = fixture.makeTestSubject()
        failed.viewModel.conversation = conversation(reply: reply)
        failed.viewModel.error = ErrorViewConfiguration(message: "The server went away.", retryActionLabel: nil)
        await failed.notifyReplyFinished(reply.id)
        #expect(fixture.notifications.posted.isEmpty)
    }

    @Test func `a private chat's notification carries neither its title nor the reply`() async {
        let fixture = Fixture()
        let subject = fixture.makeTestSubject()
        subject.viewModel.conversation = conversation(isPrivate: true, reply: reply)

        await subject.notifyReplyFinished(reply.id)

        #expect(fixture.notifications.posted.map(\.title) == [Strings.brand])
        #expect(fixture.notifications.posted.map(\.body) == [Strings.notificationReplyReady])
    }

    @Test func `a picture is announced as ready`() async {
        let fixture = Fixture()
        let subject = fixture.makeTestSubject()
        let picture = Message(role: .assistant, text: "Made in 4 s", imagesJPEG: [Data([1])])
        subject.viewModel.conversation = conversation(reply: picture)

        await subject.notifyReplyFinished(picture.id)

        #expect(fixture.notifications.posted.map(\.body) == [Strings.notificationPictureReady])
    }

    @Test func `a tapped notification opens its chat, reading the chats from disk if they have not been yet`() async {
        let saved = conversation(reply: reply)
        let fixture = Fixture(stored: [saved])
        let subject = fixture.makeTestSubject()
        #expect(fixture.conversationStore.conversations.isEmpty)

        await subject.openNotifiedConversationAction(saved.id)

        #expect(subject.viewModel.conversation.id == saved.id)
    }

    @Test(arguments: [("Samantha Example", "Sam", "Sam"), ("Samantha Example", "", "Samantha")])
    func `the greeting uses the nickname, then the first word of the full name`(fullName: String, nickname: String, name: String) {
        let fixture = Fixture(settings: ServerSettings(fullName: fullName, nickname: nickname))
        let subject = fixture.makeTestSubject()

        #expect(subject.greeting.contains(name))
        #expect(!subject.greeting.contains("Example"))
    }

    @Test func `haptics are silent while switched off`() {
        var played: [HapticKind] = []
        let output = Haptics.output
        let wasEnabled = Haptics.isEnabled
        defer {
            Haptics.output = output
            Haptics.isEnabled = wasEnabled
        }
        Haptics.output = { played.append($0) }

        Haptics.isEnabled = false
        Haptics.play(.light)
        Haptics.isEnabled = true
        Haptics.play(.soft)

        #expect(played == [.soft])
    }
}
