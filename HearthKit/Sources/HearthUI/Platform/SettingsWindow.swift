import UIKit

/// Settings in a window of their own, as a Mac app keeps them, rather than a sheet over the chat.
///
/// Only a Mac that allows the app more than one window uses it; an iPhone or iPad shows the settings as a sheet.
public enum SettingsWindow {
    /// The identifier of the scene that holds the settings window, which the app declares and opens by.
    public static let id = "settings"

    /// Whether the settings open in a window of their own here.
    @MainActor static var isUsed: Bool {
        #if targetEnvironment(macCatalyst)
        UIApplication.shared.supportsMultipleScenes
        #else
        false
        #endif
    }

    /// The scene of the settings window while it is open, so that asking for the settings again brings it forward
    /// instead of opening a second one.
    @MainActor static weak var scene: UIWindowScene?

    /// Brings the open settings window to the front.
    @MainActor
    static func bringToFront() {
        guard let session = scene?.session else {
            return
        }
        UIApplication.shared.requestSceneSessionActivation(session, userActivity: nil, options: nil, errorHandler: nil)
    }
}
