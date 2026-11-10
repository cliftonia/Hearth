import SwiftUI

/// The chat with its drawer of conversations, and the sheets presented above them.
struct RootView: View {
    let coordinator: AppCoordinator

    var body: some View {
        @Bindable var router = coordinator.router
        // Sheets are separate presentations, so each is given the chosen theme as well as the root.
        let colorScheme = coordinator.settingsStore.settings.appearance.colorScheme
        DrawerContainer(isOpen: $router.isSidebarOpen) {
            SidebarView(presenter: coordinator.sidebarPresenter)
        } content: {
            ChatView(presenter: coordinator.chatPresenter)
        }
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
