import Foundation
import HearthDomain
@testable import HearthUI
import Testing

/// How the settings keep every change as it is made, the switches with side effects, and the erasing of everything.
@MainActor
struct SettingsPresenterTests {
    /// The settings presenter with what it shares, and a record of what it told the coordinator and VoiceOver.
    @MainActor
    final class Fixture {
        let settingsStore: SettingsStore
        let conversationStore = PresenterFixtures.conversationStore([Conversation(title: "Holiday")])
        let profileStore = PresenterFixtures.profileStore()
        let memoryStore = PresenterFixtures.memoryStore()
        let syncStore = PresenterFixtures.syncStore()
        let modelStore: ModelStore
        let notifications: NotificationsFixture
        private(set) var syncNowCount = 0
        /// How often the scheduler was told that the sync settings changed.
        private(set) var settingsChangedCount = 0
        /// What a hub check answers.
        var checkAnswer: SyncHubCheckKind = .reachable
        /// How many models the chat server offers; `nil` when it cannot be reached.
        var modelCount: Int? = 0
        /// The biometrics the device has, and whether its owner passes when asked.
        var biometry: BiometryKind = .faceID
        var isOwner = true
        private(set) var authenticationReasons: [String] = []
        private(set) var announcements: [String] = []
        private(set) var didQuietChat = false
        private(set) var eraseCount = 0
        private(set) var finishCount = 0
        private(set) var chatServerChangeCount = 0
        var now = Date(timeIntervalSince1970: 1_794_788_100)

        init(settings: ServerSettings = ServerSettings(ollamaAddress: "https://a.example"), permission: NotificationPermissionKind = .notDetermined) {
            settingsStore = SettingsStore(defaults: ServerSettings(), load: { try? JSONEncoder().encode(settings) }, save: { _ in })
            notifications = NotificationsFixture(permission: permission)
            let names = ["llama3.2:latest"]
            modelStore = ModelStore { _ in names.map { ChatModel(id: ChatModel.ID($0)) } }
        }

        func makeTestSubject() -> SettingsPresenter {
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
                modelStore: modelStore,
                speech: PresenterFixtures.speech,
                image: PresenterFixtures.image,
                eraser: EraseInteractor(stores: stores),
                authentication: AuthenticationProvider(authenticate: { await self.answer($0) }, biometry: { [biometry] in biometry }),
                notifications: notifications.provider,
                fetchModels: { _ in try await self.countModels() },
                quietChat: { self.didQuietChat = true },
                sync: SettingsPresenter.SyncControls(
                    store: syncStore,
                    syncNow: { self.syncNowCount += 1 },
                    check: { _, _ in self.checkAnswer },
                    settingsChanged: { self.settingsChangedCount += 1 }
                ),
                announce: { self.announcements.append($0) },
                now: { self.now }
            ))
            subject.delegate = self
            return subject
        }

        private func answer(_ reason: String) -> Bool {
            authenticationReasons.append(reason)
            return isOwner
        }

        private func countModels() throws -> Int {
            guard let modelCount else {
                throw PresenterFixtures.Unreachable()
            }
            return modelCount
        }
    }

    @Test func `names typed on the profile page are kept, trimmed, when the field is left`() async {
        let fixture = Fixture()
        let subject = fixture.makeTestSubject()
        await subject.loadAction()

        subject.viewModel.fullName = "  Sam Example "
        subject.viewModel.nickname = "Sam"
        subject.viewModel.customInstructions = "Be brief.\n"
        #expect(fixture.settingsStore.settings.nickname.isEmpty)
        subject.keepAction()

        #expect(fixture.settingsStore.settings.profile == UserProfile(fullName: "Sam Example", nickname: "Sam"))
        #expect(fixture.settingsStore.settings.customInstructions == "Be brief.")
        #expect(fixture.finishCount == 0)
    }

    @Test func `Close keeps what was still being typed and asks for the sheet to close`() async {
        let fixture = Fixture()
        let subject = fixture.makeTestSubject()
        await subject.loadAction()

        subject.viewModel.nickname = "Sam"
        await subject.closeAction()

        #expect(fixture.settingsStore.settings.nickname == "Sam")
        #expect(fixture.finishCount == 1)
    }

    @Test func `a sheet swiped away keeps what was being typed and opens next time on the main list`() async {
        let fixture = Fixture()
        let subject = fixture.makeTestSubject()
        await subject.loadAction()
        subject.viewModel.path = [.profile]

        subject.viewModel.customInstructions = "Answer in French."
        await subject.sheetDidDismissAction()

        #expect(fixture.settingsStore.settings.customInstructions == "Answer in French.")
        #expect(subject.viewModel.path.isEmpty)
    }

    @Test func `switches and choices are kept at once`() async {
        let fixture = Fixture()
        let subject = fixture.makeTestSubject()
        await subject.loadAction()

        subject.viewModel.isHapticsEnabled = false
        subject.viewModel.isFollowUpsEnabled = false
        subject.viewModel.isPageReadingEnabled = false
        subject.viewModel.appearance = .dark
        subject.viewModel.imageModel = .krea2Turbo
        subject.keepAction()

        let saved = fixture.settingsStore.settings
        #expect(!saved.isHapticsEnabled)
        #expect(!saved.isFollowUpsEnabled)
        #expect(!saved.isPageReadingEnabled)
        #expect(saved.appearance == .dark)
        #expect(saved.imageModel == .krea2Turbo)
        #expect(fixture.finishCount == 0)
    }

    @Test func `keeping does not turn on the lock or a notification switch behind their own actions`() async {
        let fixture = Fixture()
        let subject = fixture.makeTestSubject()
        await subject.loadAction()

        subject.viewModel.isLockEnabled = true
        subject.viewModel.isReplyNotificationsEnabled = true
        subject.keepAction()

        #expect(!fixture.settingsStore.settings.isLockEnabled)
        #expect(!fixture.settingsStore.settings.isReplyNotificationsEnabled)
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

    @Test func `the scheduled tasks switch is kept at once and asks for permission the first time`() async {
        let fixture = Fixture()
        let subject = fixture.makeTestSubject()
        await subject.loadAction()

        subject.viewModel.isTaskNotificationsEnabled = true
        await subject.taskNotificationsAction()

        #expect(fixture.settingsStore.settings.isTaskNotificationsEnabled)
        #expect(!fixture.settingsStore.settings.isReplyNotificationsEnabled)
        #expect(fixture.notifications.requestCount == 1)
    }

    @Test func `erasing quiets the chat, erases through the stores, and closing afterwards writes nothing back`() async throws {
        let fixture = Fixture(settings: ServerSettings(ollamaAddress: "https://mine.example", nickname: "Sam"))
        try await fixture.conversationStore.load()
        try await fixture.profileStore.setPhoto(Data([1]))
        let subject = fixture.makeTestSubject()
        await subject.loadAction()

        await subject.eraseAction()
        await subject.sheetDidDismissAction()

        #expect(fixture.didQuietChat)
        #expect(fixture.eraseCount == 1)
        #expect(fixture.conversationStore.conversations.isEmpty)
        #expect(fixture.profileStore.photoJPEG == nil)
        #expect(fixture.settingsStore.settings == ServerSettings())
        #expect(subject.viewModel.eraseError == nil)
        #expect(fixture.chatServerChangeCount == 0)
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
    func settingsPresenterDidFinish(_ presenter: SettingsPresenter) {
        finishCount += 1
    }

    func settingsPresenterDidChangeChatServer(_ presenter: SettingsPresenter) {
        chatServerChangeCount += 1
    }

    func settingsPresenterDidErase(_ presenter: SettingsPresenter) {
        eraseCount += 1
    }
}
