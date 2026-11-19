import Foundation

// The words of the chat's menu and the chat list's, which say the same things in the same order, with "…" on what
// asks for more before it acts; the + button; and the names the canvas gives its own buttons.
extension Strings {
    static let renameEllipsis = String(localized: "sidebar.renameEllipsis", defaultValue: "Rename…", bundle: .module)
    static let moveToProjectEllipsis = String(localized: "project.moveEllipsis", defaultValue: "Move to project…", bundle: .module)
    /// The composer's + button, which holds files and photos, pictures, a scheduled task and a new project.
    static let addToChat = String(localized: "composer.addTitle", defaultValue: "Add to chat", bundle: .module)
    static let photos = String(localized: "composer.photos", defaultValue: "Photos", bundle: .module)
    static func recentPhoto(number: Int, total: Int) -> String {
        String(localized: "composer.recentPhoto", defaultValue: "Recent photo \(number) of \(total)", bundle: .module)
    }

    static let addMenu = String(localized: "composer.add", defaultValue: "Add", bundle: .module)

    static func newChatIn(project name: String) -> String {
        String(localized: "project.newChatIn", defaultValue: "New chat in \(name)", bundle: .module)
    }

    static let canvasCopyPage = String(localized: "canvas.copyPage", defaultValue: "Copy page", bundle: .module)
    static let canvasCopyDrawing = String(localized: "canvas.copyDrawing", defaultValue: "Copy drawing", bundle: .module)
    static let canvasCopyDocument = String(localized: "canvas.copyDocument", defaultValue: "Copy document", bundle: .module)
    static let canvasCopyCode = String(localized: "canvas.copyCode", defaultValue: "Copy code", bundle: .module)
    static let canvasSharePage = String(localized: "canvas.sharePage", defaultValue: "Share page", bundle: .module)
    static let canvasShareDrawing = String(localized: "canvas.shareDrawing", defaultValue: "Share drawing", bundle: .module)
    static let canvasShareDocument = String(localized: "canvas.shareDocument", defaultValue: "Share document", bundle: .module)
    static let canvasShareCode = String(localized: "canvas.shareCode", defaultValue: "Share code", bundle: .module)
}
