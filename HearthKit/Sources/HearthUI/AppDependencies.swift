import Foundation
import HearthDomain

/// The addresses the app starts with before the user has saved any of their own.
public struct AppDefaults: Sendable {
    public let ollamaAddress: String
    public let searchAddress: String
    public let speechAddress: String
    /// The model the app starts with, by its name on the server. Empty means the first one the server offers.
    public let modelName: String

    public init(ollamaAddress: String = "", searchAddress: String = "", speechAddress: String = "", modelName: String = "") {
        self.ollamaAddress = ollamaAddress
        self.searchAddress = searchAddress
        self.speechAddress = speechAddress
        self.modelName = modelName
    }
}

/// Everything the screens are built from.
@MainActor
public struct AppDependencies {
    let chat: ChatInteractor
    let speech: SpeechInteractor
    let dictation: DictationProvider
    let authentication: AuthenticationProvider
    let fetchModels: @Sendable (URL) async throws -> [ChatModel]
    let settingsStore: SettingsStore
    let modelStore: ModelStore
    let conversationStore: ConversationStore
    let memoryStore: MemoryStore

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
