import Foundation
import HearthDomain

// The notification switches and the haptics switch, which take effect as they are switched.
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
        // The form being filled as the settings open is not the user switching anything.
        guard settings.isReplyNotificationsEnabled != isEnabled else {
            return
        }
        keep(settings.updating(isReplyNotificationsEnabled: isEnabled))
        if isEnabled, await dependencies.notifications.permission() == .notDetermined {
            _ = await dependencies.notifications.requestPermission()
        }
        await refreshNotificationPermissionAction()
    }

    /// Keeps the haptics switch as it now stands, so that the next tap already follows it.
    func hapticsAction() {
        let settings = dependencies.settingsStore.settings
        guard settings.isHapticsEnabled != viewModel.isHapticsEnabled else {
            return
        }
        keep(settings.updating(isHapticsEnabled: viewModel.isHapticsEnabled))
    }

    /// Writes settings changed outside the draft.
    private func keep(_ settings: ServerSettings) {
        do {
            try dependencies.settingsStore.update(settings)
        } catch {
            logger.error("Saving a switch failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
