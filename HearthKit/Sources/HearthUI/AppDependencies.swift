import Foundation
import HearthDomain

/// Everything the screens are built from: the interactors, the providers and the stores they share.
@MainActor
public struct AppDependencies {
    let chat: ChatInteractor
    let speech: SpeechInteractor
    let image: ImageInteractor
    let research: ResearchInteractor
    let dictation: DictationProvider
    let camera: CameraProvider
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
            speech: makeSpeech(),
            image: ImageInteractor(provider: .live()),
            research: ResearchInteractor(chat: chatProvider, search: .live()),
            dictation: makeDictation(),
            camera: makeCamera(),
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

    // MARK: Simulator stand-ins

    /// The words a scripted voice conversation hears, given when the simulator launches the app as the argument
    /// `-HearthVoiceScript "words"`. `nil` on a device, in a release build, and when the argument is left out.
    private static var voiceScript: String? {
        #if DEBUG && targetEnvironment(simulator)
        UserDefaults.standard.string(forKey: "HearthVoiceScript")
        #else
        nil
        #endif
    }

    /// The device's cameras. The simulator has none, so a debug build there is given a drawn test card.
    private static func makeCamera() -> CameraProvider {
        #if DEBUG && targetEnvironment(simulator)
        .simulated()
        #else
        .live()
        #endif
    }

    /// The recogniser, or in the simulator a listener that hears the scripted words when a script is given.
    private static func makeDictation() -> DictationProvider {
        #if DEBUG && targetEnvironment(simulator)
        if let voiceScript {
            return .scripted(words: voiceScript)
        }
        #endif
        return .live()
    }

    /// The speech server and the audio player. A scripted conversation is silent and asks nothing of the speech server.
    private static func makeSpeech() -> SpeechInteractor {
        #if DEBUG && targetEnvironment(simulator)
        if voiceScript != nil {
            return SpeechInteractor(speech: .silent, playback: .silent)
        }
        #endif
        return SpeechInteractor(speech: .live(), playback: .live())
    }
}
