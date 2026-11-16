import Foundation
import HearthDomain

/// Where the app's data comes from: the servers and files on the device, or, when the simulator launches a debug
/// build with `-HearthScreenshots YES`, stand-ins holding the README's sample data.
struct AppSources {
    /// The settings of a first launch.
    let settings: ServerSettings
    /// The hub the Sync page starts with.
    let hubAddress: String
    let chat: ChatDataProvider
    let conversations: ConversationDataProvider
    let projects: ProjectDataProvider
    let memories: MemoryDataProvider
    let tasks: TaskDataProvider
    let syncStore: SyncStoreProvider
    let sync: SyncDataProvider

    /// The real thing, unless the simulator asked for the screenshot stand-ins.
    static func make(defaults: AppDefaults) -> AppSources {
        #if DEBUG && targetEnvironment(simulator)
        if UserDefaults.standard.bool(forKey: "HearthScreenshots") {
            return screenshots()
        }
        #endif
        return AppSources(
            settings: ServerSettings(
                ollamaAddress: defaults.ollamaAddress,
                searchAddress: defaults.searchAddress,
                speechAddress: defaults.speechAddress,
                imageAddress: defaults.imageAddress,
                defaultModelID: defaults.modelName.isEmpty ? nil : ChatModel.ID(defaults.modelName)
            ),
            hubAddress: defaults.hubAddress,
            chat: .live(),
            conversations: .live(),
            projects: .live(),
            memories: .live(),
            tasks: .live(),
            syncStore: .live(),
            sync: .live()
        )
    }
}

#if DEBUG && targetEnvironment(simulator)
extension AppSources {
    /// Placeholder addresses that name no real machine, a server listing sample models, a hub that keeps what it is
    /// sent, and stores that start with the sample chats, project, memories and tasks of a made-up Sam.
    private static func screenshots() -> AppSources {
        let samples = ScreenshotSamples()
        let hubAddress = "https://my-server:8765"
        return AppSources(
            settings: ServerSettings(
                ollamaAddress: "https://my-server:11434",
                searchAddress: "https://my-server:8888",
                speechAddress: "https://my-server:8880",
                imageAddress: "https://my-server:8188",
                fullName: "Sam",
                nickname: "Sam",
                defaultModelID: ScreenshotSamples.model,
                customInstructions: "Keep answers short and use metric units.",
                isReplyNotificationsEnabled: true,
                isTaskNotificationsEnabled: true
            ),
            hubAddress: hubAddress,
            chat: .screenshots(models: ScreenshotSamples.models),
            conversations: .seeded(.live(), with: samples.conversations),
            projects: .seeded(.live(), with: samples.projects),
            memories: .seeded(.live(), with: samples.memories),
            tasks: .seeded(.live(), with: samples.tasks),
            syncStore: .screenshots(settings: SyncSettings(hubAddress: hubAddress, isEnabled: true)),
            sync: .screenshots
        )
    }
}
#endif
