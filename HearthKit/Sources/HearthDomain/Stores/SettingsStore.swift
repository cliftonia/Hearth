import Foundation
import Observation

/// The server addresses and voice, shared by every screen and kept between launches.
@MainActor
@Observable
public final class SettingsStore {
    public private(set) var settings: ServerSettings

    private let save: (Data) -> Void

    /// - Parameters:
    ///   - defaults: Used until the user saves settings of their own.
    ///   - load: Reads the saved settings, if any.
    ///   - save: Writes the settings.
    public init(defaults: ServerSettings, load: () -> Data?, save: @escaping (Data) -> Void) {
        self.settings = load().flatMap { try? JSONDecoder().decode(ServerSettings.self, from: $0) } ?? defaults
        self.save = save
    }

    public func update(_ settings: ServerSettings) throws {
        self.settings = settings
        save(try JSONEncoder().encode(settings))
    }
}

public extension SettingsStore {
    static func live(defaults: ServerSettings, userDefaults: UserDefaults = .standard) -> SettingsStore {
        let key = "serverSettings"
        return SettingsStore(
            defaults: defaults,
            load: { userDefaults.data(forKey: key) },
            save: { userDefaults.set($0, forKey: key) }
        )
    }
}
