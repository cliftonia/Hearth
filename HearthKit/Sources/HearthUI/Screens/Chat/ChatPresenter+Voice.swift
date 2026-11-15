import Foundation
import HearthDomain

// Dictating into the composer and reading replies aloud.
extension ChatPresenter {
    /// Starts dictating after whatever is already in the draft, or stops if dictation is under way.
    func dictationAction() async {
        guard !viewModel.isDictating else {
            await stopDictation()
            return
        }
        // A press on the composer is already on its way to listening.
        guard !viewModel.holdToTalk.isActive, let updates = await beginListening(isStillWanted: { true }) else {
            return
        }
        let existing = viewModel.draft
        viewModel.isDictating = true
        dictationTask = Task {
            for await update in updates {
                self.viewModel.draft = [existing, update.text].filter { !$0.isEmpty }.joined(separator: " ")
            }
            self.viewModel.isDictating = false
        }
    }

    /// Ends dictation, however it was begun, and waits for the last words to arrive.
    func stopDictation() async {
        // A press still waiting for the recogniser learns here that it is no longer wanted.
        viewModel.holdToTalk.release()
        guard viewModel.isDictating else {
            return
        }
        await dependencies.dictation.stop()
        await dictationTask?.value
        viewModel.isDictating = false
    }

    /// Asks for leave to listen, silences any reading aloud and starts the recogniser, showing why if it cannot.
    ///
    /// - Parameter isStillWanted: Asked after each wait, since leave may take as long as the user takes to answer.
    ///   When it says no, the recogniser is not started, or is stopped again, and nothing is returned.
    /// - Returns: What is heard, or `nil` if listening did not begin.
    private func beginListening(isStillWanted: () -> Bool) async -> AsyncStream<DictationUpdate>? {
        guard await dependencies.dictation.requestAuthorization() else {
            viewModel.error = ErrorViewConfiguration(message: Strings.errorDictationDenied, retryActionLabel: nil)
            return nil
        }
        guard isStillWanted() else {
            return nil
        }
        await stopSpeaking()
        guard isStillWanted() else {
            return nil
        }
        do {
            let updates = try await dependencies.dictation.start()
            guard isStillWanted() else {
                await dependencies.dictation.stop()
                return nil
            }
            return updates
        } catch {
            logger.error("Dictation could not start: \(error.localizedDescription, privacy: .public)")
            viewModel.error = ErrorViewConfiguration(message: Strings.errorDictationUnavailable, retryActionLabel: nil)
            return nil
        }
    }

    // MARK: Hold to talk

    /// A finger has rested on the composer: starts recording, unless something is written or dictation is under way.
    ///
    /// The press is noted before anything is waited for, so that a release arriving straight after it is not missed.
    func holdToTalkBeganAction() {
        guard viewModel.holdToTalk.press(isDraftEmpty: viewModel.draft.isEmpty, isDictating: viewModel.isDictating) else {
            return
        }
        Task { await self.holdToTalk() }
    }

    /// The finger lifted or slid away, or the stop control was tapped. Harmless when nothing is held.
    func holdToTalkEndedAction() {
        guard viewModel.holdToTalk.release() else {
            return
        }
        Task { await self.stopDictation() }
    }

    /// Sees one press through from start to finish: listens until dictation is stopped, by the finger or by
    /// anything else, then puts what was heard into the draft. However it ends, the composer is left at rest
    /// or with words in it, never still recording.
    private func holdToTalk() async {
        let updates = await beginListening(isStillWanted: { self.viewModel.holdToTalk.isStillWanted })
        guard let updates, viewModel.holdToTalk.begin() else {
            // Refused, unavailable, or let go of before the recogniser was ready.
            if updates != nil {
                await dependencies.dictation.stop()
            }
            viewModel.holdToTalk.finish()
            return
        }
        viewModel.isDictating = true
        // The words wait in the press until it ends, so the composer keeps its resting shape under the finger.
        let listening = Task {
            for await update in updates {
                self.viewModel.holdToTalk.hear(update.text)
            }
            self.viewModel.isDictating = false
        }
        dictationTask = listening
        let levels = await dependencies.dictation.levels()
        let meter = Task {
            for await level in levels {
                self.viewModel.voiceLevel = level
            }
        }
        await listening.value
        meter.cancel()
        if !viewModel.holdToTalk.isStopRequested {
            // The recogniser gave up by itself with the finger still down; let the microphone go.
            await dependencies.dictation.stop()
        }
        viewModel.voiceLevel = 0
        guard let words = viewModel.holdToTalk.finish() else {
            return
        }
        viewModel.draft = [viewModel.draft, words].filter { !$0.isEmpty }.joined(separator: " ")
        viewModel.dictatedDraftCount += 1
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

    /// Begins reading a reply aloud while it is still being written, a sentence at a time, when the user has
    /// asked for every reply to be read. Returns the feed the reply's text is poured into, or `nil` when not reading.
    func beginNarration(of replyID: Message.ID) -> SpokenReplyFeed? {
        guard settings.isAutoReadEnabled, isSpeechAvailable, !dependencies.isLocked() else {
            return nil
        }
        let (sentences, continuation) = AsyncStream.makeStream(of: String.self)
        let speech = dependencies.speech
        let settings = settings
        viewModel.speakingMessageID = replyID
        speakTask = Task {
            do {
                try await speech.speak(sentences: sentences, settings: settings)
            } catch is CancellationError {
                // Stopped by the user.
            } catch {
                self.logger.error("Reading aloud failed: \(error.localizedDescription, privacy: .public)")
                self.viewModel.error = ErrorViewConfiguration(from: error)
            }
            if self.viewModel.speakingMessageID == replyID {
                self.viewModel.speakingMessageID = nil
            }
        }
        return SpokenReplyFeed(continuation: continuation)
    }

    /// Silences whatever is being read aloud.
    func stopSpeaking() async {
        guard viewModel.speakingMessageID != nil else {
            return
        }
        speakTask?.cancel()
        await dependencies.speech.stop()
        viewModel.speakingMessageID = nil
    }
}
