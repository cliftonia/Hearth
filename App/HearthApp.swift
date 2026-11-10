import HearthUI
import SwiftUI

@main
struct HearthApp: App {
    @State private var coordinator = AppCoordinator(dependencies: .live(defaults: .fromInfoPlist))

    var body: some Scene {
        WindowGroup {
            coordinator.start()
        }
    }
}

private extension AppDefaults {
    /// Starting addresses supplied at build time through `Config/Local.xcconfig`, so none live in the source.
    static var fromInfoPlist: AppDefaults {
        AppDefaults(
            ollamaAddress: infoValue("HearthDefaultOllamaAddress"),
            searchAddress: infoValue("HearthDefaultSearchAddress"),
            speechAddress: infoValue("HearthDefaultSpeechAddress")
        )
    }

    static func infoValue(_ key: String) -> String {
        Bundle.main.object(forInfoDictionaryKey: key) as? String ?? ""
    }
}
