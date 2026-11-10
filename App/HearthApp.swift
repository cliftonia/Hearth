import HearthUI
import SwiftUI

@main
struct HearthApp: App {
    /// Shared with the app's shortcuts, which may run before any window exists.
    @MainActor static let coordinator = AppCoordinator(dependencies: .live(defaults: .fromInfoPlist))

    var body: some Scene {
        WindowGroup {
            Self.coordinator.start()
        }
    }
}

private extension AppDefaults {
    /// Starting addresses supplied at build time through `Config/Local.xcconfig`, so none live in the source.
    static var fromInfoPlist: AppDefaults {
        AppDefaults(
            ollamaAddress: infoValue("HearthDefaultOllamaAddress"),
            searchAddress: infoValue("HearthDefaultSearchAddress"),
            speechAddress: infoValue("HearthDefaultSpeechAddress"),
            modelName: infoValue("HearthDefaultModel")
        )
    }

    static func infoValue(_ key: String) -> String {
        Bundle.main.object(forInfoDictionaryKey: key) as? String ?? ""
    }
}
