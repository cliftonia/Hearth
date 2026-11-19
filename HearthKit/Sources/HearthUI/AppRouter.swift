import Foundation
import Observation

/// The sheets that have to do with projects. Only one shows at a time, and one may give way to the other.
enum ProjectSheetKind: Hashable, Identifiable {
    /// The sheet that makes or edits a project.
    case editor
    /// The sheet that chooses a project for a chat.
    case picker

    var id: Self { self }
}

/// What is on screen besides the chat itself. The coordinator changes it and the root view presents what it says.
@MainActor
@Observable
final class AppRouter {
    /// The drawer of chats on a narrow screen. A wide screen keeps the chats in view and ignores this.
    var isSidebarOpen = false
    /// Whether the screen is wide enough to keep the chats beside the chat. The root view keeps this current.
    var isWide = false {
        didSet { matchCanvasSheet() }
    }
    /// Whether the canvas is open. A wide screen shows it beside the chat; a narrow one as a sheet.
    var isCanvasOpen = false {
        didSet { matchCanvasSheet() }
    }
    /// Whether the canvas's sheet is showing: the canvas is open and the screen is narrow. The sheet is bound to
    /// this, so a swipe that dismisses it lands here.
    var isCanvasSheetPresented = false
    /// The width the root view has to lay out in, which decides whether the chat list has room beside the canvas.
    var rootWidth: CGFloat = 0
    /// Whether a wide screen shows the chats beside the chat. Putting them away gives the chat the whole width.
    /// The choice is remembered from one launch to the next.
    var isSidebarPinned: Bool {
        didSet { defaults.set(!isSidebarPinned, forKey: Self.sidebarHiddenKey) }
    }

    /// Whether the settings open in a window of their own, as on a Mac, rather than as a sheet over the chat.
    let usesSettingsWindow: Bool

    /// Opens every folded section of the chat list again, as erasing everything does.
    func forgetSidebarFolds() {
        defaults.removeObject(forKey: SidebarFolds.storageKey)
    }
    /// Whether the settings window is open. Its scene keeps this current, so that asking for the settings again
    /// brings it forward rather than opening another.
    var isSettingsWindowShown = false

    private let defaults: UserDefaults
    private static let sidebarHiddenKey = "isSidebarHidden"

    init(defaults: UserDefaults = .standard, usesSettingsWindow: Bool = false) {
        self.defaults = defaults
        self.usesSettingsWindow = usesSettingsWindow
        isSidebarPinned = !defaults.bool(forKey: Self.sidebarHiddenKey)
    }

    /// Keeps the sheet in step with the canvas and the width of the screen.
    private func matchCanvasSheet() {
        let isWanted = isCanvasOpen && !isWide
        if isCanvasSheetPresented != isWanted {
            isCanvasSheetPresented = isWanted
        }
    }

    /// Whether the settings are showing: as a sheet over the chat, or in their own window where `usesSettingsWindow`.
    var isSettingsPresented = false
    /// Whether the app is in front of the user. The root view keeps this current; a reply that finishes while it
    /// is `false` may be announced with a notification.
    var isSceneActive = true
    var isVoicePresented = false
    /// The project sheet that is showing, if one is.
    var projectSheet: ProjectSheetKind?
    /// The task sheet over the chat that is showing, if one is: the editor, or the notice that tasks need sync.
    var taskSheet: TaskSheetKind?

    /// Closes the drawer of chats, Settings, any project sheet and any task sheet, so that the chat underneath can
    /// be reached. Voice and the canvas are left as they are.
    func closeOverlays() {
        isSidebarOpen = false
        isSettingsPresented = false
        projectSheet = nil
        taskSheet = nil
    }
}
