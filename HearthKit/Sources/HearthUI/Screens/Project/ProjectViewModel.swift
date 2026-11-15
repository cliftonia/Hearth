import HearthDomain
import Observation

/// The project sheet: a draft of the project, bound to its fields, and the state of the sheet's own controls.
@MainActor
@Observable
final class ProjectViewModel {
    // MARK: Draft

    /// The project being edited; `nil` while a new one is being made.
    var editingID: Project.ID?
    var name = ""
    var instructions = ""
    /// The reference files, already reduced to their text.
    var documents: [AttachedDocument] = []

    // MARK: Sheet state

    var isConfirmingDelete = false
    /// Whether to say that some of the files picked could not be read.
    var isShowingUnreadableFiles = false
    /// Whether to say that the project could not be saved or deleted.
    var isShowingSaveFailure = false

    /// Whether an existing project is being edited, which is what can be deleted.
    var isExisting: Bool { editingID != nil }

    /// A project needs a name to be listed under; nothing else is required of it.
    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
