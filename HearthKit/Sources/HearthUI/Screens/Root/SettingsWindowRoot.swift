import SwiftUI

/// The settings in a window of their own, as on a Mac. The window shows the same presenters as the sheet would, so
/// what is changed here reaches the chat at once.
///
/// It follows the router: closing the window closes the settings, and anything that closes the settings, such as the
/// lock or a tapped notification, closes the window. While the app is locked or hidden it shows nothing.
struct SettingsWindowRoot: View {
    let coordinator: AppCoordinator

    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        let router = coordinator.router
        let lock = coordinator.lockPresenter.viewModel
        let isCovered = lock.isLocked || lock.isObscured
        let colorScheme = coordinator.settingsStore.settings.appearance.colorScheme
        SettingsView(presenter: coordinator.settingsPresenter, tasksPresenter: coordinator.tasksPresenter, isInWindow: true)
            .opacity(isCovered ? 0 : 1)
            .allowsHitTesting(!isCovered)
            .accessibilityHidden(isCovered)
            .background(HearthColor.paper.ignoresSafeArea())
            .windowMinimumSize(WindowMinimumSize.settings)
            .onWindowScene { scene in
                SettingsWindow.scene = scene
                scene.title = Strings.settings
                // A window made after the theme was chosen does not inherit it, so it is given it here.
                for window in scene.windows {
                    window.overrideUserInterfaceStyle = InterfaceStyle.style(for: colorScheme)
                }
            }
            // A window the system brings back at launch counts as the settings being open.
            .onAppear {
                router.isSettingsWindowShown = true
                router.isSettingsPresented = true
            }
            .onDisappear {
                router.isSettingsWindowShown = false
                SettingsWindow.scene = nil
                if router.isSettingsPresented {
                    router.isSettingsPresented = false
                }
                // What was being typed is kept, as when the sheet goes.
                coordinator.settingsSheetDidDismiss()
            }
            .onChange(of: router.isSettingsPresented) {
                if !router.isSettingsPresented {
                    dismissWindow(id: SettingsWindow.id)
                }
            }
            // A locked app shows no settings: a window brought back at launch, or open when the app locks, closes.
            .onChange(of: lock.isLocked, initial: true) {
                if lock.isLocked {
                    router.isSettingsPresented = false
                    dismissWindow(id: SettingsWindow.id)
                }
            }
            .tint(HearthColor.pine)
    }
}

/// Presents the settings from the chat: as a sheet, or, where the settings have a window of their own, by opening
/// that window, unless it is open already.
struct SettingsPresentation: ViewModifier {
    let coordinator: AppCoordinator

    @Environment(\.openWindow) private var openWindow

    func body(content: Content) -> some View {
        @Bindable var router = coordinator.router
        let usesWindow = router.usesSettingsWindow
        content
            .sheet(isPresented: usesWindow ? .constant(false) : $router.isSettingsPresented, onDismiss: coordinator.settingsSheetDidDismiss) {
                SettingsView(presenter: coordinator.settingsPresenter, tasksPresenter: coordinator.tasksPresenter, isInWindow: false)
            }
            .onChange(of: router.isSettingsPresented) {
                if usesWindow, router.isSettingsPresented, !router.isSettingsWindowShown {
                    openWindow(id: SettingsWindow.id)
                }
            }
    }
}
