import HearthUI
import SwiftUI

/// The app itself: one window, whose contents the coordinator supplies, and on a Mac a second for the settings.
@main
struct HearthApp: App {
    /// Shared with the app's shortcuts, which may run before any window exists.
    @MainActor static let coordinator = AppCoordinator(dependencies: .live(defaults: .fromInfoPlist))

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Self.coordinator.start()
                // A link from the share extension only says that something is waiting, which is then taken in.
                .onOpenURL { url in
                    Self.coordinator.open(url)
                    Task { await Self.importSharedAction() }
                }
                // Whatever the share sheet left is also taken in each time the app comes to the front.
                .task(id: scenePhase) {
                    if scenePhase == .active {
                        await Self.importSharedAction()
                    }
                }
        }
        // New Chat, Settings, Search Chats, the chat list and Delete Chat, in the Mac's menu bar and on a keyboard.
        .commands {
            HearthCommands(coordinator: Self.coordinator)
        }
        #if !targetEnvironment(macCatalyst)
        // Now and then the system wakes the app for one sync, which brings in what scheduled tasks have filed.
        .backgroundTask(.appRefresh(BackgroundRefresh.identifier)) {
            await Self.coordinator.backgroundRefreshAction()
        }
        #endif
        #if targetEnvironment(macCatalyst)
        // Settings… and ⌘, open the settings in a window of their own, as a Mac app keeps them, showing the same
        // presenters as the chat's window.
        WindowGroup(id: SettingsWindow.id) {
            Self.coordinator.settingsWindow()
        }
        #endif
    }

    @MainActor
    private static func importSharedAction() async {
        if let inbox = sharedInboxURL {
            await coordinator.importShared(from: inbox)
        }
    }

    /// Where the share extension leaves things, inside the folder the app group shares.
    private static var sharedInboxURL: URL? {
        let group = AppDefaults.infoValue("HearthAppGroup")
        guard !group.isEmpty else {
            return nil
        }
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)?
            .appendingPathComponent("Inbox", isDirectory: true)
    }
}

extension AppDefaults {
    /// Starting addresses supplied at build time through `Config/Local.xcconfig`, so none live in the source.
    static var fromInfoPlist: AppDefaults {
        AppDefaults(
            ollamaAddress: infoValue("HearthDefaultOllamaAddress"),
            searchAddress: infoValue("HearthDefaultSearchAddress"),
            speechAddress: infoValue("HearthDefaultSpeechAddress"),
            imageAddress: infoValue("HearthDefaultImageAddress"),
            hubAddress: infoValue("HearthDefaultHubAddress"),
            modelName: infoValue("HearthDefaultModel")
        )
    }

    /// A string from the app's Info.plist; empty when the key is missing.
    static func infoValue(_ key: String) -> String {
        Bundle.main.object(forInfoDictionaryKey: key) as? String ?? ""
    }
}
