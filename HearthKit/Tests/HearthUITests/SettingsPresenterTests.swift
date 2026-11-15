import Foundation
import HearthDomain
@testable import HearthUI
import Testing

/// How the settings keep the profile, the switches that take effect at once, and the erasing of everything.
@MainActor
struct SettingsPresenterTests {
    /// The settings presenter with what it shares, and a record of what it told the coordinator.
    @MainActor
    final class Fixture {
        let settingsStore: SettingsStore
        let conversationStore = PresenterFixtures.conversationStore([Conversation(title: "Holiday")])
        let profileStore = PresenterFixtures.profileStore()
        let syncStore = PresenterFixtures.syncStore()
        let notifications: NotificationsFixture
        private(set) var syncNowCount = 0
        /// What a hub check answers.
        var checkAnswer: SyncHubCheckKind = .reachable
        private(set) var didQuietChat = false
        private(set) var eraseCount = 0
        private(set) var finishes: [Bool] = []

        init(settings: ServerSettings = ServerSettings(ollamaAddress: "https://a.example"), permission: NotificationPermissionKind = .notDetermined) {
            settingsStore = SettingsStore(defaults: ServerSettings(), load: { try? JSONEncoder().encode(settings) }, save: { _ in })
            notifications = NotificationsFixture(permission: permission)
        }

        func makeTestSubject() -> SettingsPresenter {
            let memoryStore = PresenterFixtures.memoryStore()
            let stores = EraseInteractor.Stores(
                conversations: conversationStore,
                projects: PresenterFixtures.projectStore(),
                memories: memoryStore,
                profile: profileStore,
                settings: settingsStore
            )
            let subject = SettingsPresenter(dependencies: SettingsPresenter.Dependencies(
                settingsStore: settingsStore,
                memoryStore: memoryStore,
                profileStore: profileStore,
                speech: PresenterFixtures.speech,
                image: PresenterFixtures.image,
                eraser: EraseInteractor(stores: stores),
                authentication: AuthenticationProvider { _ in true },
                notifications: notifications.provider,
                fetchModels: { _ in 0 },
                quietChat: { self.didQuietChat = true },
                sync: SettingsPresenter.SyncControls(
                    store: syncStore,
                    syncNow: { self.syncNowCount += 1 },
                    check: { _, _ in self.checkAnswer }
                )
            ))
            subject.delegate = self
            return subject
        }
    }

    @Test func `names typed on the profile page are kept by Done, trimmed`() async {
        let fixture = Fixture()
        let subject = fixture.makeTestSubject()
        await subject.loadAction()

        subject.viewModel.fullName = "  Sam Example "
        subject.viewModel.nickname = "Sam"
        subject.viewModel.customInstructions = "Be brief.\n"
        #expect(fixture.settingsStore.settings.nickname.isEmpty)
        subject.saveAction()

        #expect(fixture.settingsStore.settings.profile == UserProfile(fullName: "Sam Example", nickname: "Sam"))
        #expect(fixture.settingsStore.settings.customInstructions == "Be brief.")
        #expect(fixture.finishes == [true])
    }

    @Test func `names typed and then cancelled are let go`() async {
        let fixture = Fixture()
        let subject = fixture.makeTestSubject()
        await subject.loadAction()

        subject.viewModel.nickname = "Sam"
        subject.cancelAction()

        #expect(fixture.settingsStore.settings.nickname.isEmpty)
        #expect(fixture.finishes == [false])
    }

    @Test func `turning Replies on asks for permission the first time and takes effect at once`() async {
        let fixture = Fixture()
        let subject = fixture.makeTestSubject()
        await subject.loadAction()

        subject.viewModel.isReplyNotificationsEnabled = true
        await subject.replyNotificationsAction()

        #expect(fixture.notifications.requestCount == 1)
        #expect(fixture.settingsStore.settings.isReplyNotificationsEnabled)
        #expect(subject.viewModel.notificationPermission == .allowed)
    }

    @Test func `a refusal leaves the switch on and is shown, and the user is not asked again`() async {
        let fixture = Fixture()
        fixture.notifications.allowsWhenAsked = false
        let subject = fixture.makeTestSubject()
        await subject.loadAction()

        subject.viewModel.isReplyNotificationsEnabled = true
        await subject.replyNotificationsAction()
        subject.viewModel.isReplyNotificationsEnabled = false
        await subject.replyNotificationsAction()
        subject.viewModel.isReplyNotificationsEnabled = true
        await subject.replyNotificationsAction()

        #expect(fixture.notifications.requestCount == 1)
        #expect(subject.viewModel.notificationPermission == .denied)
        #expect(fixture.settingsStore.settings.isReplyNotificationsEnabled)
    }

    @Test func `opening the settings with Replies already on asks nothing`() async {
        let fixture = Fixture(settings: ServerSettings(isReplyNotificationsEnabled: true))
        let subject = fixture.makeTestSubject()

        await subject.loadAction()
        await subject.replyNotificationsAction()

        #expect(subject.viewModel.isReplyNotificationsEnabled)
        #expect(fixture.notifications.requestCount == 0)
    }

    @Test func `the haptics switch takes effect at once and survives Done`() async {
        let fixture = Fixture()
        let subject = fixture.makeTestSubject()
        await subject.loadAction()
        #expect(subject.viewModel.isHapticsEnabled)

        subject.viewModel.isHapticsEnabled = false
        subject.hapticsAction()
        #expect(!fixture.settingsStore.settings.isHapticsEnabled)

        subject.saveAction()
        #expect(!fixture.settingsStore.settings.isHapticsEnabled)
    }

    @Test func `erasing quiets the chat, erases through the stores and tells the coordinator`() async throws {
        let fixture = Fixture(settings: ServerSettings(ollamaAddress: "https://mine.example", nickname: "Sam"))
        try await fixture.conversationStore.load()
        try await fixture.profileStore.setPhoto(Data([1]))
        let subject = fixture.makeTestSubject()
        await subject.loadAction()

        await subject.eraseAction()

        #expect(fixture.didQuietChat)
        #expect(fixture.eraseCount == 1)
        #expect(fixture.conversationStore.conversations.isEmpty)
        #expect(fixture.profileStore.photoJPEG == nil)
        #expect(fixture.settingsStore.settings == ServerSettings())
        #expect(subject.viewModel.profileError == nil)
    }

    @Test func `a photo that could not be read is said, and the old one stays`() async throws {
        let fixture = Fixture()
        try await fixture.profileStore.setPhoto(Data([1]))
        let subject = fixture.makeTestSubject()

        await subject.setPhotoAction(nil)

        #expect(subject.photoJPEG == Data([1]))
        #expect(subject.viewModel.profileError != nil)

        await subject.removePhotoAction()
        #expect(subject.photoJPEG == nil)
        #expect(subject.viewModel.profileError == nil)
    }
}

extension SettingsPresenterTests.Fixture: SettingsPresenterDelegate {
    func settingsPresenterDidFinish(_ presenter: SettingsPresenter, didSave: Bool) {
        finishes.append(didSave)
    }

    func settingsPresenterDidErase(_ presenter: SettingsPresenter) {
        eraseCount += 1
    }
}
