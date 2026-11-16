import Foundation
import HearthDomain

/// The four server addresses, trimmed, as they were last acted on.
struct ServerAddresses: Hashable {
    var chat = ""
    var search = ""
    var speech = ""
    var image = ""

    init() {}

    init(_ settings: ServerSettings) {
        chat = settings.ollamaAddress
        search = settings.searchAddress
        speech = settings.speechAddress
        image = settings.imageAddress
    }
}

// The servers page, the voice page's sample and list of voices, and what the picture server can do.
extension SettingsPresenter {
    /// An address field was left, or its page closed: the addresses are kept, and each server whose address
    /// changed is asked afresh. Nothing is asked while an address is still being typed.
    func serverAddressesEditedAction() async {
        keepAction()
        let addresses = ServerAddresses(settingsStore.settings)
        let before = actedOnAddresses
        guard addresses != before else {
            return
        }
        actedOnAddresses = addresses
        if addresses.chat != before.chat {
            viewModel.connectionCheck = .idle
            delegate?.settingsPresenterDidChangeChatServer(self)
        }
        if addresses.speech != before.speech {
            await loadVoicesAction()
        }
        if addresses.image != before.image {
            await loadImageModelsAction()
        }
    }

    /// Checks that the chat server answers, and says how many models it offers, aloud too for VoiceOver.
    func testAction() async {
        await serverAddressesEditedAction()
        guard draft.ollamaURL != nil else {
            viewModel.connectionCheck = .failed(message: Strings.invalidAddress)
            dependencies.announce(Strings.invalidAddress)
            return
        }
        viewModel.connectionCheck = .checking
        do {
            let count = try await dependencies.fetchModels(draft)
            viewModel.connectionCheck = .succeeded(modelCount: count)
            dependencies.announce(Strings.testSucceeded(modelCount: count))
        } catch {
            logger.error("Connection test failed: \(error.localizedDescription, privacy: .public)")
            let message = ErrorViewConfiguration(from: error).message
            viewModel.connectionCheck = .failed(message: message)
            dependencies.announce(message)
        }
    }

    /// Asks the picture server what it can do, which fills the list of models. Asking wakes the server if it is asleep.
    func loadImageModelsAction() async {
        viewModel.imageCapabilities = (try? await dependencies.image.capabilities(settings: draft)) ?? ImageCapabilities()
    }

    /// The list of voices is a convenience; without it the voice is typed by name.
    func loadVoicesAction() async {
        viewModel.voices = (try? await dependencies.speech.voices(settings: draft)) ?? []
    }

    /// Whether a speech server is set, without which there is no voice to choose.
    var hasSpeechServer: Bool {
        !viewModel.speechAddress.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: Voice sample

    /// Speaks a short sample in the chosen voice, or silences the sample if it is playing.
    func previewVoiceAction() async {
        let wasPlaying = viewModel.voicePreview == .playing
        await stopVoicePreviewAction()
        guard !wasPlaying else {
            return
        }
        viewModel.voicePreview = .playing
        let speech = dependencies.speech
        let settings = draft
        let task = Task {
            do {
                try await speech.speak(text: Strings.voiceSample, settings: settings)
            } catch is CancellationError {
                // Stopped by the user.
            } catch {
                self.logger.error("Playing the voice sample failed: \(error.localizedDescription, privacy: .public)")
                self.viewModel.voicePreview = .failed
            }
        }
        previewTask = task
        await task.value
        // A sample that was stopped, or replaced by another, has already been accounted for.
        if previewTask == task, viewModel.voicePreview == .playing {
            viewModel.voicePreview = .idle
        }
    }

    /// Silences the sample, as when another voice is chosen or the settings are closed.
    func stopVoicePreviewAction() async {
        guard let previewTask else {
            viewModel.voicePreview = .idle
            return
        }
        self.previewTask = nil
        previewTask.cancel()
        await dependencies.speech.stop()
        viewModel.voicePreview = .idle
    }

    /// The voice changed: the sample of the last one stops. A voice chosen from the server's list is kept at once;
    /// one typed by name is kept when its field is left.
    func voiceChangedAction() async {
        await stopVoicePreviewAction()
        if !viewModel.voices.isEmpty {
            keepAction()
        }
    }
}
