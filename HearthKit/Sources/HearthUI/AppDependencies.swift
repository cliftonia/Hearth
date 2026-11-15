import Foundation
import HearthDomain

/// Everything the screens are built from: the interactors, the providers and the stores they share.
@MainActor
public struct AppDependencies {
    let chat: ChatInteractor
    let speech: SpeechInteractor
    let image: ImageInteractor
    let dictation: DictationProvider
    let authentication: AuthenticationProvider
    let notifications: NotificationProvider
    /// Lists the models at a server address, for testing a connection without touching the model store.
    let fetchModels: @Sendable (URL) async throws -> [ChatModel]
    let settingsStore: SettingsStore
    let modelStore: ModelStore
    let conversationStore: ConversationStore
    let memoryStore: MemoryStore
    let projectStore: ProjectStore
    let projects: ProjectInteractor
    let profileStore: ProfileStore
    let eraser: EraseInteractor

    /// The real thing, talking to the servers and the device. The defaults seed the settings on first launch.
    public static func live(defaults: AppDefaults) -> AppDependencies {
        let chatProvider = ChatDataProvider.live()
        let settings = ServerSettings(
            ollamaAddress: defaults.ollamaAddress,
            searchAddress: defaults.searchAddress,
            speechAddress: defaults.speechAddress,
            imageAddress: defaults.imageAddress,
            defaultModelID: defaults.modelName.isEmpty ? nil : ChatModel.ID(defaults.modelName)
        )
        let conversationStore = ConversationStore(provider: .live())
        let projectStore = ProjectStore(provider: .live())
        let memoryStore = MemoryStore(provider: .live())
        let profileStore = ProfileStore(provider: .live())
        let settingsStore = SettingsStore.live(defaults: settings)
        let notifications = NotificationProvider.live()
        let stores = EraseInteractor.Stores(
            conversations: conversationStore,
            projects: projectStore,
            memories: memoryStore,
            profile: profileStore,
            settings: settingsStore
        )
        return AppDependencies(
            chat: ChatInteractor(chat: chatProvider, search: .live()),
            speech: SpeechInteractor(speech: .live(), playback: .live()),
            image: ImageInteractor(provider: .live()),
            dictation: .live(),
            authentication: .live(),
            notifications: notifications,
            fetchModels: chatProvider.fetchModels,
            settingsStore: settingsStore,
            modelStore: ModelStore(fetchModels: chatProvider.fetchModels),
            conversationStore: conversationStore,
            memoryStore: memoryStore,
            projectStore: projectStore,
            projects: ProjectInteractor(projectStore: projectStore, conversationStore: conversationStore),
            profileStore: profileStore,
            eraser: EraseInteractor(stores: stores, removeNotifications: notifications.removeAll)
        )
    }
}
