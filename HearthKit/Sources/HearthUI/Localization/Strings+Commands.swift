import Foundation

// The commands in the Mac's menu bar and in the list an iPad shows while Command is held, in Title Case as menus
// are, and the questions that confirm deleting a chat and letting go of changes.
// swiftlint:disable line_length
extension Strings {
    static let commandNewChat = String(localized: "command.newChat", defaultValue: "New Chat", bundle: .module)
    static let commandSettings = String(localized: "command.settings", defaultValue: "Settings…", bundle: .module)
    static let commandSearchChats = String(localized: "command.searchChats", defaultValue: "Search Chats", bundle: .module)
    static let commandShowChatList = String(localized: "command.showChatList", defaultValue: "Show Chat List", bundle: .module)
    static let commandHideChatList = String(localized: "command.hideChatList", defaultValue: "Hide Chat List", bundle: .module)
    static let commandDeleteChat = String(localized: "command.deleteChat", defaultValue: "Delete Chat…", bundle: .module)

    static let deleteChatQuestion = String(localized: "chat.deleteQuestion", defaultValue: "Delete this chat?", bundle: .module)
    static let deleteChat = String(localized: "chat.deleteChat", defaultValue: "Delete Chat", bundle: .module)
    static let deleteChatDetail = String(localized: "chat.deleteDetail", defaultValue: "This cannot be undone.", bundle: .module)
    static let deleteChatSyncedDetail = String(localized: "chat.deleteSyncedDetail", defaultValue: "It will be removed from all your devices that sync. This cannot be undone.", bundle: .module)

    static let discardChangesQuestion = String(localized: "editor.discardQuestion", defaultValue: "Discard your changes?", bundle: .module)
    static let discardChanges = String(localized: "editor.discard", defaultValue: "Discard Changes", bundle: .module)
    static let keepEditing = String(localized: "editor.keepEditing", defaultValue: "Keep Editing", bundle: .module)
}
// swiftlint:enable line_length
