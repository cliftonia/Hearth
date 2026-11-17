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

    /// Whether to ask before letting go of changes, as when Cancel is tapped after typing.
    var isConfirmingDiscard = false

    /// The draft as the sheet opened with it, to tell whether anything has been changed since.
    var original = ProjectDraft(name: "", instructions: "", documentIDs: [])

    /// Whether an existing project is being edited, which is what can be deleted.
    var isExisting: Bool { editingID != nil }

    /// The draft as it stands.
    var current: ProjectDraft {
        ProjectDraft(name: name, instructions: instructions, documentIDs: documents.map(\.id))
    }

    /// Whether anything has been typed, added or removed since the sheet opened. While it has, the sheet cannot be
    /// swiped away, and Cancel asks first.
    var hasChanges: Bool {
        current != original
    }

    /// A project needs a name to be listed under; nothing else is required of it.
    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// What the project sheet edits, compared to tell whether it has been changed.
struct ProjectDraft: Equatable {
    let name: String
    let instructions: String
    let documentIDs: [AttachedDocument.ID]
}
