import Foundation
import HearthDomain

/// Everything the screens are built from: the interactors, the providers and the stores they share.
@MainActor
public struct AppDependencies {
    let chat: ChatInteractor
    let speech: SpeechInteractor
    let dictation: DictationProvider
    let authentication: AuthenticationProvider
    /// Lists the models at a server address, for testing a connection without touching the model store.
    let fetchModels: @Sendable (URL) async throws -> [ChatModel]
    let settingsStore: SettingsStore
    let modelStore: ModelStore
    let conversationStore: ConversationStore
    let memoryStore: MemoryStore

    /// The real thing, talking to the servers and the device. The defaults seed the settings on first launch.
    public static func live(defaults: AppDefaults) -> AppDependencies {
        let chatProvider = ChatDataProvider.live()
        let settings = ServerSettings(
            ollamaAddress: defaults.ollamaAddress,
            searchAddress: defaults.searchAddress,
            speechAddress: defaults.speechAddress,
            defaultModelID: defaults.modelName.isEmpty ? nil : ChatModel.ID(defaults.modelName)
        )
        return AppDependencies(
            chat: ChatInteractor(chat: chatProvider, search: .live()),
            speech: SpeechInteractor(speech: .live(), playback: .live()),
            dictation: .live(),
            authentication: .live(),
            fetchModels: chatProvider.fetchModels,
            settingsStore: .live(defaults: settings),
            modelStore: ModelStore(fetchModels: chatProvider.fetchModels),
            conversationStore: ConversationStore(provider: .live()),
            memoryStore: MemoryStore(provider: .live())
        )
    }
}
