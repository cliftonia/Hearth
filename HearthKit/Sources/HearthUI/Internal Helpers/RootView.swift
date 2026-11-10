import SwiftUI

/// The chat with its conversations beside it or in a drawer, the sheets presented above them, and the lock over all.
struct RootView: View {
    static let sidebarWidth: CGFloat = 320

    let coordinator: AppCoordinator

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var router = coordinator.router
        // Sheets are separate presentations, so each is given the chosen theme as well as the root.
        let colorScheme = coordinator.settingsStore.settings.appearance.colorScheme
        let lock = coordinator.lockPresenter.viewModel
        layout(isSidebarOpen: $router.isSidebarOpen)
        .overlay {
            if lock.isLocked || lock.isObscured {
                LockView(presenter: coordinator.lockPresenter)
            }
        }
        .task(id: scenePhase) { await coordinator.lockPresenter.sceneAction(scenePhase) }
        .sheet(isPresented: $router.isSettingsPresented) {
            SettingsView(presenter: coordinator.settingsPresenter)
                .preferredColorScheme(colorScheme)
        }
        .fullScreenCover(isPresented: $router.isVoicePresented) {
            VoiceView(presenter: coordinator.voicePresenter)
                .preferredColorScheme(colorScheme)
        }
        .tint(HearthColor.pine)
        .preferredColorScheme(colorScheme)
    }

    /// On a wide screen the conversations stay beside the chat; on a phone they slide in as a drawer.
    @ViewBuilder
    private func layout(isSidebarOpen: Binding<Bool>) -> some View {
        if horizontalSizeClass == .regular {
            HStack(spacing: 0) {
                SidebarView(presenter: coordinator.sidebarPresenter)
                    .frame(width: Self.sidebarWidth)
                Rectangle()
                    .fill(HearthColor.line)
                    .frame(width: 1)
                    .ignoresSafeArea()
                ChatView(presenter: coordinator.chatPresenter)
            }
            .background(HearthColor.paper.ignoresSafeArea())
        } else {
            DrawerContainer(isOpen: isSidebarOpen) {
                SidebarView(presenter: coordinator.sidebarPresenter)
            } content: {
                ChatView(presenter: coordinator.chatPresenter)
            }
        }
    }
}

/// A panel that slides in from the leading edge over dimmed content, by button or by drag.
struct DrawerContainer<Drawer: View, Content: View>: View {
    @Binding var isOpen: Bool
    @ViewBuilder let drawer: Drawer
    @ViewBuilder let content: Content

    @GestureState private var dragTranslationX: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let width = min(proxy.size.width * 0.84, 340)
            let progress = min(max(((isOpen ? width : 0) + dragTranslationX) / width, 0), 1)
            ZStack(alignment: .leading) {
                content
                    .accessibilityHidden(isOpen)
                Color.black
                    .opacity(0.32 * progress)
                    .ignoresSafeArea()
                    .allowsHitTesting(isOpen)
                    .onTapGesture { isOpen = false }
                    .accessibilityHidden(true)
                drawer
                    .frame(width: width)
                    .offset(x: (progress - 1) * width)
                    .accessibilityHidden(!isOpen)
            }
            .simultaneousGesture(dragGesture(width: width))
            .animation(.snappy(duration: 0.28), value: isOpen)
            .animation(.interactiveSpring, value: dragTranslationX)
        }
    }

    private func dragGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 20)
            .updating($dragTranslationX) { value, state, _ in
                guard abs(value.translation.width) > abs(value.translation.height) else {
                    return
                }
                state = value.translation.width
            }
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else {
                    return
                }
                let travel = value.predictedEndTranslation.width
                if isOpen, travel < -width / 3 {
                    isOpen = false
                } else if !isOpen, travel > width / 3 {
                    isOpen = true
                }
            }
    }
}
