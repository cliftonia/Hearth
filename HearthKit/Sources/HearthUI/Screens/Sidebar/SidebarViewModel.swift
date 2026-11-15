import HearthDomain
import Observation

/// The chat list's own state: what is being searched for, the project being looked at, and the chat being renamed.
@MainActor
@Observable
final class SidebarViewModel {
    /// The words typed into the search field.
    var query = ""
    /// The project whose chats alone are listed; `nil` lists every chat.
    var selectedProjectID: Project.ID?
    /// Whether the rename alert is showing.
    var isRenaming = false
    var renameDraft = ""
    var renamingID: Conversation.ID?
    /// Whether to say that a change to a chat could not be saved.
    var isShowingSaveFailure = false
}
