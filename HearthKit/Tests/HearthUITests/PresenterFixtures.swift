import Foundation
import HearthDomain
@testable import HearthUI

/// Stand-ins for what presenters are built from: stores that keep nothing on disk and servers that never answer.
@MainActor
enum PresenterFixtures {
    /// What a server that is not there throws.
    struct Unreachable: Error {}

    static func conversationStore(_ stored: [Conversation] = []) -> ConversationStore {
        ConversationStore(provider: ConversationDataProvider(loadAll: { stored }, save: { _ in }, delete: { _ in }, deleteAll: {}))
    }

    static func projectStore() -> ProjectStore {
        ProjectStore(provider: ProjectDataProvider(loadAll: { [] }, save: { _ in }, delete: { _ in }, deleteAll: {}))
    }

    static func memoryStore() -> MemoryStore {
        MemoryStore(provider: MemoryDataProvider(load: { [] }, save: { _ in }))
    }

    static func taskStore(_ stored: [ScheduledTask] = []) -> TaskStore {
        TaskStore(provider: TaskDataProvider(loadAll: { stored }, save: { _ in }, delete: { _ in }, deleteAll: {}))
    }

    static func profileStore() -> ProfileStore {
        ProfileStore(provider: ProfilePhotoProvider(load: { nil }, save: { _ in }, delete: {}))
    }

    /// A sync store kept in memory, with the given settings.
    static func syncStore(_ settings: SyncSettings = SyncSettings()) -> SyncStore {
        let saved = SyncMemory(settings: try? JSONEncoder().encode(settings))
        return SyncStore(provider: SyncStoreProvider(
            loadSettings: { saved.settings },
            saveSettings: { saved.settings = $0 },
            loadJournal: { nil },
            saveJournal: { _ in },
            readToken: { saved.token },
            writeToken: { saved.token = $0 }
        ))
    }

    static func settingsStore(_ settings: ServerSettings = ServerSettings()) -> SettingsStore {
        SettingsStore(defaults: settings, load: { nil }, save: { _ in })
    }

    static var chat: ChatInteractor {
        let provider = ChatDataProvider(
            fetchModels: { _ in [] },
            streamChat: { _, _ in AsyncThrowingStream { $0.finish() } },
            complete: { _, _ in "" }
        )
        return ChatInteractor(chat: provider, search: SearchDataProvider { _, _ in [] })
    }

    static var speech: SpeechInteractor {
        SpeechInteractor(
            speech: SpeechDataProvider(synthesize: { _, _, _ in Data() }, fetchVoices: { _ in [] }),
            playback: AudioPlaybackProvider(play: { _ in }, stop: {})
        )
    }

    static var image: ImageInteractor {
        ImageInteractor(provider: ImageDataProvider(fetchCapabilities: { _ in ImageCapabilities() }, render: { _, _, _, _ in throw Unreachable() }))
    }

    /// Research with a chat server that says nothing and a search that finds nothing.
    static var research: ResearchInteractor {
        let provider = ChatDataProvider(
            fetchModels: { _ in [] },
            streamChat: { _, _ in AsyncThrowingStream { $0.finish() } },
            complete: { _, _ in "" }
        )
        return ResearchInteractor(chat: provider, search: SearchDataProvider { _, _ in [] })
    }

    /// A photo library that takes every picture.
    static var photoLibrary: PhotoLibraryProvider {
        PhotoLibraryProvider { _ in }
    }

    static var dictation: DictationProvider {
        DictationProvider(requestAuthorization: { false }, start: { AsyncStream { $0.finish() } }, stop: {})
    }

    /// A chat presenter over the given stores, with servers that never answer.
    static func chatPresenter(
        conversationStore: ConversationStore = conversationStore(),
        isSyncOn: @escaping @MainActor () -> Bool = { false }
    ) -> ChatPresenter {
        ChatPresenter(dependencies: ChatPresenter.Dependencies(
            chat: chat,
            speech: speech,
            image: image,
            research: research,
            dictation: dictation,
            notifications: NotificationsFixture().provider,
            photoLibrary: photoLibrary,
            settingsStore: settingsStore(),
            modelStore: ModelStore(fetchModels: { _ in [] }),
            conversationStore: conversationStore,
            memoryStore: memoryStore(),
            projectStore: projectStore(),
            isLocked: { false },
            isOnScreen: { true },
            announce: { _ in },
            isVoiceOverRunning: { false },
            isSyncOn: isSyncOn
        ))
    }
}

/// The identifiers a store in a test was asked to delete, safely across tasks.
final class DeletedIDs<ID: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [ID] = []

    var all: [ID] {
        lock.withLock { stored }
    }

    func record(_ id: ID) {
        lock.withLock { stored.append(id) }
    }
}

/// The system's notifications as a test sees them: what the user would answer, and what was asked and posted.
@MainActor
final class NotificationsFixture {
    var permission: NotificationPermissionKind
    /// What the user answers when the system asks them.
    var allowsWhenAsked = true
    private(set) var requestCount = 0
    private(set) var posted: [ReplyNotification] = []

    init(permission: NotificationPermissionKind = .notDetermined) {
        self.permission = permission
    }

    var provider: NotificationProvider {
        NotificationProvider(
            permission: { await self.permission },
            requestPermission: { await self.answerRequest() },
            post: { await self.record($0) }
        )
    }

    private func answerRequest() -> Bool {
        requestCount += 1
        permission = allowsWhenAsked ? .allowed : .denied
        return allowsWhenAsked
    }

    private func record(_ notification: ReplyNotification) {
        posted.append(notification)
    }
}

/// What a sync store in memory has saved, safely across tasks.
final class SyncMemory: @unchecked Sendable {
    private let lock = NSLock()
    private var storedSettings: Data?
    private var storedToken: String?

    init(settings: Data?) {
        storedSettings = settings
    }

    var settings: Data? {
        get { lock.withLock { storedSettings } }
        set { lock.withLock { storedSettings = newValue } }
    }

    var token: String? {
        get { lock.withLock { storedToken } }
        set { lock.withLock { storedToken = newValue } }
    }
}
