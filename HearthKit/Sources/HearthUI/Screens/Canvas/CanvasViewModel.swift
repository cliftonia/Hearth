import HearthDomain
import Observation

/// The two ways the canvas shows a piece.
enum CanvasModeKind: Hashable {
    /// As it is meant to be seen: a page, a drawing or a laid-out document.
    case preview
    /// As it was written.
    case code
}

/// The canvas's own state: which piece was opened, which of its versions is looked at, and how it is shown.
///
/// None of it is saved. The pieces themselves are read from the chat's messages each time.
@MainActor
@Observable
final class CanvasViewModel {
    /// The piece the canvas was opened for, whose versions it steps between. `nil` until one has been opened.
    var anchor: CanvasReference?
    /// The version being looked at. `nil` follows the newest, so a version that arrives is shown as it is written.
    var selected: CanvasReference?
    /// How a piece that can be previewed is shown.
    var mode = CanvasModeKind.preview
    /// Counts the copies made, for the haptic that confirms each.
    var copyCount = 0
}

/// What the canvas draws: one version of a piece, and where it stands among the others.
struct CanvasViewConfiguration: Hashable {
    let title: String
    /// The kind in words and the length, for the line under the title.
    let detail: String
    let kind: CanvasKind
    let text: String
    /// Whether it is still being written by a reply on its way.
    let isWriting: Bool
    /// Where this version stands among them all, counting from one.
    let versionNumber: Int
    let versionCount: Int
    /// How it is shown: the chosen way, or code for a piece that has no other or is not yet finished.
    let mode: CanvasModeKind

    var hasEarlier: Bool { versionNumber > 1 }
    var hasLater: Bool { versionNumber < versionCount }
}
