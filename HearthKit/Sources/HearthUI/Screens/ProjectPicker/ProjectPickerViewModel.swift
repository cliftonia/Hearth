import HearthDomain
import Observation

/// The project picker's own state: the chat a project is being chosen for.
@MainActor
@Observable
final class ProjectPickerViewModel {
    /// The chat to be filed. `nil` until the picker has been opened for one.
    var conversationID: Conversation.ID?
    /// The project the chat is in as the picker opens, which is ticked; `nil` when it is in none.
    var currentProjectID: Project.ID?
    /// Whether to say that the chat could not be moved.
    var isShowingSaveFailure = false
}
