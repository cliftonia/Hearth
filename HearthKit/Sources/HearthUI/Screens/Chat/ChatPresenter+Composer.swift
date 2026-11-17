import Foundation

/// What the composer's main button does at this moment.
enum ComposerPrimaryKind: Hashable {
    /// Stops the reply that is streaming.
    case stop
    /// Sends what has been written.
    case send
    /// Starts a voice conversation, when there is nothing to send.
    case voice
}

// The composer's main button, which stops, sends or starts a voice conversation as the moment needs.
extension ChatPresenter {
    var primaryKind: ComposerPrimaryKind {
        if viewModel.isStreaming {
            return .stop
        }
        return viewModel.canSend ? .send : .voice
    }

    /// Stops a reply that is streaming, sends a message that is written, and otherwise starts a voice conversation.
    func primaryAction() async {
        switch primaryKind {
        case .stop:
            await stopAction()
        case .send:
            await sendAction()
        case .voice:
            voiceAction()
        }
    }
}
