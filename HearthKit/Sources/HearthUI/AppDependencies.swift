import Foundation
import HearthCore
import HearthDomain
import os

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
    let photoLibrary: PhotoLibraryProvider
    /// Lists the models at a server address, for testing a connection without touching the model store.
    let fetchModels: @Sendable (URL) async throws -> [ChatModel]
    let settingsStore: SettingsStore
    let modelStore: ModelStore
    let conversationStore: ConversationStore
    let memoryStore: MemoryStore
    let projectStore: ProjectStore
    /// This device's copy of the scheduled tasks, which the hub runs.
    let taskStore: TaskStore
    let projects: ProjectInteractor
    let profileStore: ProfileStore
    let eraser: EraseInteractor
    let syncStore: SyncStore
    let sync: SyncInteractor
    let syncScheduler: SyncScheduler
    /// Filled in by the coordinator once the chat exists.
    let syncHooks: SyncHooks

    /// The real thing, talking to the servers and the device. The defaults seed the settings on first launch.
    public static func live(defaults: AppDefaults) -> AppDependencies {
        let sources = AppSources.make(defaults: defaults)
        let chatProvider = sources.chat
        let conversationStore = ConversationStore(provider: sources.conversations)
        let projectStore = ProjectStore(provider: sources.projects)
        let memoryStore = MemoryStore(provider: sources.memories)
        let taskStore = TaskStore(provider: sources.tasks)
        let profileStore = ProfileStore(provider: .live())
        let settingsStore = SettingsStore.live(defaults: sources.settings)
        let notifications = NotificationProvider.live()
        let syncStore = SyncStore(provider: sources.syncStore, defaultHubAddress: sources.hubAddress)
        let syncHooks = SyncHooks()
        let syncStores = SyncInteractor.Stores(
            conversations: conversationStore, projects: projectStore, memories: memoryStore, tasks: taskStore, sync: syncStore
        )
        let (sync, syncScheduler) = makeSync(stores: syncStores, provider: sources.sync, hooks: syncHooks)
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
            photoLibrary: .live(),
            fetchModels: chatProvider.fetchModels,
            settingsStore: settingsStore,
            modelStore: ModelStore(fetchModels: chatProvider.fetchModels),
            conversationStore: conversationStore,
            memoryStore: memoryStore,
            projectStore: projectStore,
            taskStore: taskStore,
            projects: ProjectInteractor(projectStore: projectStore, conversationStore: conversationStore),
            profileStore: profileStore,
            eraser: EraseInteractor(stores: stores, removeNotifications: notifications.removeAll) {
                await syncScheduler.stopAndReset()
                await forgetTasks(taskStore)
            },
            syncStore: syncStore,
            sync: sync,
            syncScheduler: syncScheduler,
            syncHooks: syncHooks
        )
    }

    /// Sync against the hub, and what decides when it runs. Each store tells sync of the changes made on this
    /// device: a deletion is noted at once, and a sync follows a few seconds after any change.
    private static func makeSync(
        stores: SyncInteractor.Stores,
        provider: SyncDataProvider,
        hooks: SyncHooks
    ) -> (SyncInteractor, SyncScheduler) {
        let sync = SyncInteractor(
            stores: stores,
            provider: provider,
            isBusy: { hooks.isBusy($0) },
            didApplyRemote: { hooks.didApplyRemote($0) },
            didReceiveTaskResults: { hooks.didReceiveTaskResults($0) }
        )
        let scheduler = SyncScheduler(store: stores.sync, interactor: sync)
        let syncStore = stores.sync
        let record: @MainActor (SyncLocalChangeKind) -> Void = { change in
            syncStore.record(change)
            scheduler.localChangeHappened()
        }
        stores.conversations.onLocalChange = record
        stores.projects.onLocalChange = record
        stores.memories.onLocalChange = record
        stores.tasks.onLocalChange = record
        return (sync, scheduler)
    }

    /// Lets go of this device's copy of the tasks once sync has been forgotten, as erasing does. They live on the hub,
    /// which keeps running them; a copy that cannot be removed is read again from the hub when sync is next set up.
    private static func forgetTasks(_ store: TaskStore) async {
        do {
            try await store.deleteAll()
        } catch {
            Logger(for: AppDependencies.self).error("Removing the scheduled tasks failed: \(error.localizedDescription, privacy: .public)")
        }
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
