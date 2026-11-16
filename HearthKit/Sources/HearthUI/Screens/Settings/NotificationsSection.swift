import HearthDomain
import SwiftUI
import UIKit

/// The row in the settings that leads to the notification switches, saying whether any is on.
struct NotificationsSection: View {
    let presenter: SettingsPresenter
    /// Opens the page this row leads to.
    let openAction: (SettingsPageKind) -> Void

    var body: some View {
        let isOn = presenter.viewModel.isReplyNotificationsEnabled || presenter.viewModel.isTaskNotificationsEnabled
        Section {
            SettingsLinkRow(action: { openAction(.notifications) }, label: {
                HStack(spacing: HearthSpacing.s8) {
                    Text(Strings.notifications)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(isOn ? Strings.notificationOn : Strings.notificationOff)
                        .foregroundStyle(HearthColor.mute)
                }
            })
        }
    }
}

/// What Hearth may tell the user about while it is not on screen: one switch for each thing it can do today.
struct NotificationsPage: View {
    let presenter: SettingsPresenter

    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var viewModel = presenter.viewModel
        // The system's refusal only matters while a switch is on.
        let isDenied = viewModel.notificationPermission == .denied && (viewModel.isReplyNotificationsEnabled || viewModel.isTaskNotificationsEnabled)
        SettingsPage(title: Strings.notifications) {
            SettingsCard(footer: Strings.notificationsFooter) {
                SettingsSwitchRow(title: Strings.notifyReplies, detail: Strings.notifyRepliesDetail, isOn: $viewModel.isReplyNotificationsEnabled)
                    .onChange(of: viewModel.isReplyNotificationsEnabled) { Task { await presenter.replyNotificationsAction() } }
                Hairline()
                    .padding(.leading, HearthSpacing.s16)
                SettingsSwitchRow(title: Strings.notifyTasks, detail: Strings.notifyTasksDetail, isOn: $viewModel.isTaskNotificationsEnabled)
                    .onChange(of: viewModel.isTaskNotificationsEnabled) { Task { await presenter.taskNotificationsAction() } }
                // A switch for each kind of notification still to come goes here, as a row of this card beneath a
                // `Hairline`: finished research, once Hearth can do it. None is shown until it does something.
            }
            deniedNotice
                .opacity(isDenied ? 1 : 0)
                .frame(height: isDenied ? nil : 0, alignment: .top)
                .clipped()
                .allowsHitTesting(isDenied)
                .accessibilityHidden(!isDenied)
        }
        .animation(.snappy, value: isDenied)
        .task { await presenter.refreshNotificationPermissionAction() }
        // The user may have been to the Settings app and back.
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                Task { await presenter.refreshNotificationPermissionAction() }
            }
        }
    }

    /// Says that the system is holding notifications back, and leads to where that is changed.
    private var deniedNotice: some View {
        PermissionNotice(systemImage: "bell.slash", message: Strings.notificationsDenied, actionTitle: Strings.notificationsOpenSettings) {
            if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                openURL(url)
            }
        }
    }
}
