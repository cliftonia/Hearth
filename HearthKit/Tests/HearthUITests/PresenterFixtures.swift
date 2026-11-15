import Foundation
import HearthDomain
@testable import HearthUI

/// Stand-ins for what presenters are built from: stores that keep nothing on disk and servers that never answer.
@MainActor
enum PresenterFixtures {
    /// What a server that is not there throws.
    struct Unreachable: Error {}

    static func conversationStore(_ stored: [Conversation] = []) -> ConversationStore {
        ConversationStore(provider: ConversationDataProvider(loadAll: { stored }, save: { _ in }, delete: { _ in }))
    }

    static func projectStore() -> ProjectStore {
        ProjectStore(provider: ProjectDataProvider(loadAll: { [] }, save: { _ in }, delete: { _ in }))
    }

    static func memoryStore() -> MemoryStore {
        MemoryStore(provider: MemoryDataProvider(load: { [] }, save: { _ in }))
    }

    static func profileStore() -> ProfileStore {
        ProfileStore(provider: ProfilePhotoProvider(load: { nil }, save: { _ in }, delete: {}))
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

    static var dictation: DictationProvider {
        DictationProvider(requestAuthorization: { false }, start: { AsyncStream { $0.finish() } }, stop: {})
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
