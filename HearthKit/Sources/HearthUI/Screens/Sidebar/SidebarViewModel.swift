import HearthDomain
import Observation

/// The chat list's own state: what is being searched for, and the chat being renamed.
@MainActor
@Observable
final class SidebarViewModel {
    /// The words typed into the search field.
    var query = ""
    /// Whether the rename alert is showing.
    var isRenaming = false
    var renameDraft = ""
    var renamingID: Conversation.ID?
}
