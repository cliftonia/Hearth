import Foundation
import HearthDomain

// The notification switches, which may ask the system for permission as they are switched on.
extension SettingsPresenter {
    /// Asks the system whether notifications are allowed, as the page appears and each time the app comes back
    /// from the Settings app, where the answer may have changed.
    func refreshNotificationPermissionAction() async {
        viewModel.notificationPermission = await dependencies.notifications.permission()
    }

    /// Keeps the Replies switch as it now stands. Turning it on asks the system for permission, which the system
    /// puts to the user only the first time; a refusal leaves the switch on and the page says where to allow it.
    func replyNotificationsAction() async {
        let isEnabled = viewModel.isReplyNotificationsEnabled
        let settings = dependencies.settingsStore.settings
        // The screen being filled as the settings open is not the user switching anything.
        guard settings.isReplyNotificationsEnabled != isEnabled else {
            return
        }
        keep(settings.updating(isReplyNotificationsEnabled: isEnabled))
        if isEnabled, await dependencies.notifications.permission() == .notDetermined {
            _ = await dependencies.notifications.requestPermission()
        }
        await refreshNotificationPermissionAction()
    }

    /// Keeps the Scheduled tasks switch as it now stands, asking for permission as the Replies switch does.
    func taskNotificationsAction() async {
        let isEnabled = viewModel.isTaskNotificationsEnabled
        let settings = dependencies.settingsStore.settings
        guard settings.isTaskNotificationsEnabled != isEnabled else {
            return
        }
        keep(settings.updating(isTaskNotificationsEnabled: isEnabled))
        if isEnabled, await dependencies.notifications.permission() == .notDetermined {
            _ = await dependencies.notifications.requestPermission()
        }
        await refreshNotificationPermissionAction()
    }

    /// Writes a notification switch, which the rest of the settings carry over as saved.
    private func keep(_ settings: ServerSettings) {
        do {
            try dependencies.settingsStore.update(settings)
        } catch {
            logger.error("Saving a switch failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
