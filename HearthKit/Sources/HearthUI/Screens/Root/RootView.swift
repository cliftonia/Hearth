import SwiftUI

/// The chat with its conversations beside it or in a drawer, the sheets presented above them, and the lock over all.
struct RootView: View {
    let coordinator: AppCoordinator

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var router = coordinator.router
        let colorScheme = coordinator.settingsStore.settings.appearance.colorScheme
        let lock = coordinator.lockPresenter.viewModel
        let isCovered = lock.isLocked || lock.isObscured
        layout(isSidebarOpen: $router.isSidebarOpen)
        // This overlay covers the chat from the first frame; the lock window covers everything presented above it.
        .overlay {
            if isCovered {
                LockView(presenter: coordinator.lockPresenter)
            }
        }
        .onChange(of: scenePhase, initial: true) {
            coordinator.router.isSceneActive = scenePhase == .active
            let shouldPrompt = coordinator.lockPresenter.sceneChanged(to: scenePhase)
            coordinator.showLockWindow(colorScheme: colorScheme)
            if shouldPrompt {
                Task { await coordinator.lockPresenter.unlockAction() }
            }
        }
        // Every haptic in the app asks this one switch.
        .onChange(of: coordinator.settingsStore.settings.isHapticsEnabled, initial: true) {
            Haptics.isEnabled = coordinator.settingsStore.settings.isHapticsEnabled
        }
        .onChange(of: horizontalSizeClass, initial: true) { coordinator.router.isWide = horizontalSizeClass == .regular }
        .onChange(of: isCovered) { coordinator.showLockWindow(colorScheme: colorScheme) }
        .onChange(of: colorScheme) { coordinator.showLockWindow(colorScheme: colorScheme) }
        // Sheets are separate presentations, so each is given the chosen theme as well as the root.
        .sheet(isPresented: $router.isSettingsPresented) {
            SettingsView(presenter: coordinator.settingsPresenter)
                .preferredColorScheme(colorScheme)
        }
        .sheet(item: $router.projectSheet) { sheet in
            projectSheet(sheet)
                .preferredColorScheme(colorScheme)
        }
        .fullScreenCover(isPresented: $router.isVoicePresented) {
            VoiceView(presenter: coordinator.voicePresenter)
                .preferredColorScheme(colorScheme)
        }
        .tint(HearthColor.pine)
        .preferredColorScheme(colorScheme)
    }

    /// The sheet that makes or edits a project, or the one that files a chat in a project.
    @ViewBuilder
    private func projectSheet(_ sheet: ProjectSheetKind) -> some View {
        switch sheet {
        case .editor:
            ProjectView(presenter: coordinator.projectPresenter)
        case .picker:
            ProjectPickerView(presenter: coordinator.projectPickerPresenter)
        }
    }

    /// On a wide screen the conversations stay beside the chat; on a phone they slide in as a drawer.
    @ViewBuilder
    private func layout(isSidebarOpen: Binding<Bool>) -> some View {
        if horizontalSizeClass == .regular {
            let isPinned = coordinator.router.isSidebarPinned
            HStack(spacing: 0) {
                // Put away, the chats keep their own width and slide out of sight, so nothing in them is rebuilt.
                SidebarView(presenter: coordinator.sidebarPresenter)
                    .frame(width: HearthSize.sidebarWidth)
                    .frame(width: isPinned ? HearthSize.sidebarWidth : 0, alignment: .trailing)
                    .clipped()
                    .allowsHitTesting(isPinned)
                    .accessibilityHidden(!isPinned)
                Hairline(axis: .vertical)
                    .ignoresSafeArea()
                    .opacity(isPinned ? 1 : 0)
                ChatView(presenter: coordinator.chatPresenter)
            }
            .background(HearthColor.paper.ignoresSafeArea())
            .animation(.snappy(duration: 0.28), value: isPinned)
        } else {
            DrawerContainer(isOpen: isSidebarOpen) {
                SidebarView(presenter: coordinator.sidebarPresenter)
            } content: {
                ChatView(presenter: coordinator.chatPresenter)
            }
        }
    }
}
