import Observation

/// What is on screen besides the chat itself. The coordinator changes it and the root view presents what it says.
@MainActor
@Observable
final class AppRouter {
    /// The drawer of chats on a narrow screen. A wide screen keeps the chats in view and ignores this.
    var isSidebarOpen = false
    var isSettingsPresented = false
    var isVoicePresented = false
}
