import Observation

/// What is on screen besides the chat itself. The coordinator changes it and the root view presents what it says.
@MainActor
@Observable
final class AppRouter {
    /// The drawer of chats on a narrow screen. A wide screen keeps the chats in view and ignores this.
    var isSidebarOpen = false
    /// Whether the screen is wide enough to keep the chats beside the chat. The root view keeps this current.
    var isWide = false
    /// Whether a wide screen shows the chats beside the chat. Putting them away gives the chat the whole width.
    var isSidebarPinned = true
    var isSettingsPresented = false
    var isVoicePresented = false
}
