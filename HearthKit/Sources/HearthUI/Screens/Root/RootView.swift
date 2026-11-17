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
        // Not a `.task(id:)`: the unlock prompt itself makes the app inactive, which must not cancel the prompt.
        .onChange(of: scenePhase, initial: true) {
            let phase = scenePhase
            Task { await coordinator.sceneAction(phase) }
        }
        // Every haptic in the app asks this one switch.
        .onChange(of: coordinator.settingsStore.settings.isHapticsEnabled, initial: true) {
            Haptics.isEnabled = coordinator.settingsStore.settings.isHapticsEnabled
        }
        .onChange(of: horizontalSizeClass, initial: true) { coordinator.router.isWide = horizontalSizeClass == .regular }
        .onChange(of: isCovered) { coordinator.showLockWindow(colorScheme: colorScheme) }
        .onChange(of: colorScheme, initial: true) {
            // Set on the windows, the theme reaches every sheet and cover presented above the chat as well.
            InterfaceStyle.apply(colorScheme)
            coordinator.showLockWindow(colorScheme: colorScheme)
        }
        .modifier(SettingsPresentation(coordinator: coordinator))
        .sheet(item: $router.taskSheet, onDismiss: coordinator.taskSheetDidDismiss) { sheet in
            taskSheet(sheet)
        }
        .sheet(item: $router.projectSheet) { sheet in
            projectSheet(sheet)
        }
        // On a narrow screen the canvas is a sheet of the full height; a wide one shows it beside the chat.
        .sheet(isPresented: $router.isCanvasSheetPresented, onDismiss: coordinator.canvasSheetDidDismiss) {
            CanvasView(presenter: coordinator.canvasPresenter)
                .presentationDetents([.large])
        }
        // The canvas belongs to the chat it was opened from: it closes when its piece is no longer there.
        .onChange(of: coordinator.chatPresenter.viewModel.conversation.id) { coordinator.canvasPresenter.chatChangedAction() }
        .onChange(of: coordinator.chatPresenter.viewModel.conversation.messages.count) { coordinator.canvasPresenter.chatChangedAction() }
        .fullScreenCover(isPresented: $router.isVoicePresented) {
            VoiceView(presenter: coordinator.voicePresenter)
        }
        .tint(HearthColor.pine)
        // On a Mac the window cannot be made so small that the chat list and the chat no longer fit.
        .windowMinimumSize(WindowMinimumSize.chat)
    }

    /// The editor of a task begun from the composer, or the notice that tasks need sync.
    @ViewBuilder
    private func taskSheet(_ sheet: TaskSheetKind) -> some View {
        switch sheet {
        case .editor:
            ChatTaskEditorSheet(presenter: coordinator.tasksPresenter)
        case .needsSync:
            TaskSyncNoticeSheet(presenter: coordinator.tasksPresenter)
        }
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

    /// The chat list, the chat and the canvas side by side. The chat list is put away by its button, or for as
    /// long as the canvas is open on a screen without room for all three.
    private func wideLayout(width: CGFloat) -> some View {
        let isCanvasOpen = coordinator.router.isCanvasOpen
        let columns = CanvasLayout.columns(
            totalWidth: width,
            isSidebarPinned: coordinator.router.isSidebarPinned,
            isCanvasOpen: isCanvasOpen,
            sidebarWidth: HearthSize.sidebarWidth
        )
        let isSidebarShown = columns.sidebarWidth > 0
        return HStack(spacing: 0) {
            // Put away, the chats keep their own width and slide out of sight, so nothing in them is rebuilt.
            SidebarView(presenter: coordinator.sidebarPresenter)
                .frame(width: HearthSize.sidebarWidth)
                .frame(width: columns.sidebarWidth, alignment: .trailing)
                .clipped()
                .allowsHitTesting(isSidebarShown)
                .accessibilityHidden(!isSidebarShown)
            Hairline(axis: .vertical)
                .ignoresSafeArea()
                .opacity(isSidebarShown ? 1 : 0)
            ChatView(presenter: coordinator.chatPresenter)
            // The canvas is only in the tree while it is open, so a closed one reads nothing from the chat.
            if isCanvasOpen {
                Hairline(axis: .vertical)
                    .ignoresSafeArea()
                CanvasView(presenter: coordinator.canvasPresenter)
                    .frame(width: columns.canvasWidth)
                    .transition(.move(edge: .trailing))
            }
        }
        .background(HearthColor.paper.ignoresSafeArea())
        .animation(.snappy(duration: 0.28), value: columns)
    }

    /// On a wide screen the conversations stay beside the chat; on a phone they slide in as a drawer.
    @ViewBuilder
    private func layout(isSidebarOpen: Binding<Bool>) -> some View {
        if horizontalSizeClass == .regular {
            GeometryReader { proxy in
                wideLayout(width: proxy.size.width)
                    .onChange(of: proxy.size.width, initial: true) { coordinator.router.rootWidth = proxy.size.width }
            }
        } else {
            DrawerContainer(isOpen: isSidebarOpen) {
                SidebarView(presenter: coordinator.sidebarPresenter)
            } content: {
                ChatView(presenter: coordinator.chatPresenter)
            }
        }
    }
}
