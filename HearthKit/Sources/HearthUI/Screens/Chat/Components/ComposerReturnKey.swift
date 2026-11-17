import SwiftUI

/// What Return from a hardware keyboard does in the composer.
enum ComposerReturnKey {
    enum OutcomeKind: Equatable {
        /// The field starts a new line, as Return does on the on-screen keyboard.
        case newLine
        /// What is written is sent.
        case send
        /// Nothing: there is nothing to send, or a reply is still on its way.
        case nothing
    }

    /// Shift-Return starts a new line; Return alone sends when there is something to send and no reply is on its way.
    nonisolated static func outcome(modifiers: EventModifiers, canSend: Bool, isStreaming: Bool) -> OutcomeKind {
        if modifiers.contains(.shift) {
            return .newLine
        }
        return canSend && !isStreaming ? .send : .nothing
    }
}
