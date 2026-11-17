import HearthDomain
import Testing

/// When sync counts as running: switched on, with an address that can be used.
struct SyncSettingsActiveTests {
    @Test(arguments: [
        (SyncSettings(hubAddress: "https://hub.example", isEnabled: true), true),
        (SyncSettings(hubAddress: "hub.example", isEnabled: true), true),
        (SyncSettings(hubAddress: "https://hub.example", isEnabled: false), false),
        (SyncSettings(hubAddress: "", isEnabled: true), false),
        (SyncSettings(hubAddress: "   ", isEnabled: true), false)
    ])
    func `sync is active only when switched on with a usable address`(settings: SyncSettings, isActive: Bool) {
        #expect(settings.isActive == isActive)
    }
}
