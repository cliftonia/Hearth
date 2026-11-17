import HearthDomain
import SwiftUI

/// The settings: one list of rows, most leading to a page of their own. As a sheet it closes by the round close
/// button at the trailing edge, as every sheet that is not an editor does; in a window of its own, as on a Mac, by the
/// window's own controls.
///
/// Every change is kept as it is made; there is no Done and no Cancel. The rows say how things stand on the page they
/// lead to, so that most settings can be read without opening anything.
struct SettingsView: View {
    let presenter: SettingsPresenter
    /// The scheduled tasks page, a screen of its own pushed from here.
    let tasksPresenter: ScheduledTasksPresenter
    /// Whether the settings have a window of their own, which closes by its own controls rather than a button here.
    let isInWindow: Bool

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var viewModel = presenter.viewModel
        NavigationStack(path: $viewModel.path) {
            Form {
                ProfileSection(presenter: presenter, openAction: openAction)
                SettingsChatsSection(presenter: presenter, tasksPresenter: tasksPresenter, openAction: openAction)
                SettingsVoicePicturesSection(presenter: presenter, openAction: openAction)
                Section {
                    SettingsStatusRow(title: Strings.notifications, status: presenter.notificationsStatus) { openAction(.notifications) }
                } header: {
                    SettingsSectionHeader(title: Strings.notifications)
                }
                SettingsAppearancePrivacySection(presenter: presenter)
                SettingsServersSyncSection(presenter: presenter, openAction: openAction)
                SettingsEraseSection(presenter: presenter)
            }
            .scrollContentBackground(.hidden)
            .background(HearthColor.paper)
            .navigationDestination(for: SettingsPageKind.self, destination: page)
            .navigationTitle(Strings.settings)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isInWindow {
                    ToolbarItem(placement: .topBarTrailing) {
                        // The system draws the symbol as its own round close button in the bar.
                        Button(action: { Task { await presenter.closeAction() } }, label: {
                            Label(Strings.close, systemImage: "xmark")
                                .labelStyle(.iconOnly)
                                .foregroundStyle(HearthColor.ink)
                        })
                        .tint(HearthColor.ink)
                        .accessibilityLabel(Strings.close)
                        .keyboardShortcut(.cancelAction)
                    }
                }
            }
        }
        .tint(HearthColor.pine)
        .task { await presenter.loadAction() }
        // What is being typed is kept if the app is left in the middle of it.
        .onChange(of: scenePhase) {
            if scenePhase != .active {
                presenter.keepAction()
            }
        }
    }

    // MARK: Pages

    /// Opens a page, unless it is already the one on top.
    private func openAction(_ kind: SettingsPageKind) {
        guard presenter.viewModel.path.last != kind else {
            return
        }
        presenter.viewModel.path.append(kind)
    }

    /// The page a row leads on to.
    @ViewBuilder
    private func page(_ kind: SettingsPageKind) -> some View {
        switch kind {
        case .profile:
            ProfilePage(presenter: presenter)
        case .memories:
            MemoryPage(presenter: presenter)
        case .webSearch:
            WebSearchPage(presenter: presenter)
        case .tasks:
            ScheduledTasksPage(presenter: tasksPresenter, openAction: openAction)
        case .voice:
            VoicePage(presenter: presenter)
        case .pictures:
            PicturesPage(presenter: presenter)
        case .notifications:
            NotificationsPage(presenter: presenter)
        case .servers:
            ServersPage(presenter: presenter)
        case .sync:
            SyncPage(presenter: presenter)
        }
    }
}

/// A heading over a section of the main list, in Title Case as written rather than in capitals.
struct SettingsSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .textCase(nil)
            .accessibilityAddTraits(.isHeader)
    }
}
