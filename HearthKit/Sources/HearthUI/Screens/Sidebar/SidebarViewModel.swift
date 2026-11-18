import HearthDomain
import Observation

/// The chat list's own state: what is being searched for, the project being looked at, and the chat being renamed.
@MainActor
@Observable
final class SidebarViewModel {
    /// The words typed into the search field.
    var query = ""
    /// Whether the search field has been opened with its button. Kept here, not in the view, so that it outlasts the
    /// view being built afresh as the keyboard rises. The field also shows while it holds words.
    var isSearchOpen = false
    /// The project whose chats alone are listed; `nil` lists every chat.
    var selectedProjectID: Project.ID?
    /// Whether the rename alert is showing.
    var isRenaming = false
    var renameDraft = ""
    var renamingID: Conversation.ID?
    /// Whether to say that a change to a chat could not be saved.
    var isShowingSaveFailure = false
    /// The chat whose deletion is being asked about; the question shows while it is set.
    var deletingID: Conversation.ID?
    /// Whether the question that confirms deleting a chat is showing. Bound to the dialog, which clears it on any answer.
    var isConfirmingDelete: Bool {
        get { deletingID != nil }
        set {
            if !newValue {
                deletingID = nil
            }
        }
    }
    /// Counts the requests to put the cursor in the search field, as the keyboard's Find makes.
    var searchFocusRequestCount = 0
}
