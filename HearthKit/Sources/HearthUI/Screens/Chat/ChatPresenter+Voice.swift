import Foundation
import HearthDomain

// Dictating into the composer and reading replies aloud.
extension ChatPresenter {
    func dictationAction() async {
        guard !viewModel.isDictating else {
            await stopDictation()
            return
        }
        guard await dependencies.dictation.requestAuthorization() else {
            viewModel.error = ErrorViewConfiguration(message: Strings.errorDictationDenied, retryActionLabel: nil)
            return
        }
        await stopSpeaking()
        do {
            let updates = try await dependencies.dictation.start()
            let existing = viewModel.draft
            viewModel.isDictating = true
            dictationTask = Task {
                for await update in updates {
                    self.viewModel.draft = [existing, update.text].filter { !$0.isEmpty }.joined(separator: " ")
                }
                self.viewModel.isDictating = false
            }
        } catch {
            logger.error("Dictation could not start: \(error.localizedDescription, privacy: .public)")
            viewModel.error = ErrorViewConfiguration(message: Strings.errorDictationUnavailable, retryActionLabel: nil)
        }
    }

    func stopDictation() async {
        guard viewModel.isDictating else {
            return
        }
        await dependencies.dictation.stop()
        await dictationTask?.value
        viewModel.isDictating = false
    }

    /// Reads a reply aloud, or stops if that reply is already being read.
    func speakAction(_ id: Message.ID) async {
        let wasSpeaking = viewModel.speakingMessageID == id
        await stopSpeaking()
        guard !wasSpeaking, let message = viewModel.conversation.messages.first(where: { $0.id == id }) else {
            return
        }
        viewModel.speakingMessageID = id
        let speech = dependencies.speech
        let settings = settings
        let task = Task {
            do {
                try await speech.speak(text: message.text, settings: settings)
            } catch is CancellationError {
                // Stopped by the user.
            } catch {
                self.logger.error("Reading aloud failed: \(error.localizedDescription, privacy: .public)")
                self.viewModel.error = ErrorViewConfiguration(from: error)
            }
        }
        speakTask = task
        await task.value
        if viewModel.speakingMessageID == id {
            viewModel.speakingMessageID = nil
        }
    }

    func stopSpeaking() async {
        guard viewModel.speakingMessageID != nil else {
            return
        }
        speakTask?.cancel()
        await dependencies.speech.stop()
        viewModel.speakingMessageID = nil
    }
}
