import Foundation
import HearthCore
import HearthDomain
import os

/// What the settings tell the coordinator: that the sheet should close, and whether anything was saved.
@MainActor
protocol SettingsPresenterDelegate: AnyObject {
    func settingsPresenterDidFinish(_ presenter: SettingsPresenter, didSave: Bool)
}

/// Edits a draft of the settings, which is kept only when the user taps Done.
///
/// The theme and the memories are the exceptions: they take effect at once.
@MainActor
final class SettingsPresenter {
    let viewModel = SettingsViewModel()
    weak var delegate: (any SettingsPresenterDelegate)?

    private let settingsStore: SettingsStore
    private let speech: SpeechInteractor
    private let fetchModels: @Sendable (ServerSettings) async throws -> Int
    private let authentication: AuthenticationProvider
    private let memoryStore: MemoryStore
    private let logger = Logger(for: SettingsPresenter.self)
    private var previewTask: Task<Void, Never>?

    /// - Parameter fetchModels: Counts the models the given settings can reach, without changing any shared state.
    init(
        settingsStore: SettingsStore,
        speech: SpeechInteractor,
        authentication: AuthenticationProvider,
        memoryStore: MemoryStore,
        fetchModels: @escaping @Sendable (ServerSettings) async throws -> Int
    ) {
        self.settingsStore = settingsStore
        self.speech = speech
        self.authentication = authentication
        self.memoryStore = memoryStore
        self.fetchModels = fetchModels
    }

    // MARK: Loading

    /// Fills the draft from the saved settings each time the sheet opens.
    func loadAction() async {
        let settings = settingsStore.settings
        viewModel.ollamaAddress = settings.ollamaAddress
        viewModel.searchAddress = settings.searchAddress
        viewModel.speechAddress = settings.speechAddress
        viewModel.voice = settings.voice
        viewModel.appearance = settings.appearance
        viewModel.customInstructions = settings.customInstructions
        viewModel.isAutoReadEnabled = settings.isAutoReadEnabled
        viewModel.isLockEnabled = settings.isLockEnabled
        viewModel.isFollowUpsEnabled = settings.isFollowUpsEnabled
        viewModel.isPageReadingEnabled = settings.isPageReadingEnabled
        viewModel.isMemoryEnabled = settings.isMemoryEnabled
        viewModel.newMemoryText = ""
        viewModel.connectionCheck = .idle
        viewModel.voicePreview = .idle
        await loadVoicesAction()
    }

    /// The list of voices is a convenience; without it the voice is typed by name.
    func loadVoicesAction() async {
        viewModel.voices = (try? await speech.voices(settings: draft)) ?? []
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
        let speech = speech
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
        await speech.stop()
        viewModel.voicePreview = .idle
    }

    // MARK: Connection, theme and lock

    /// Checks that the Ollama address in the draft answers, and says how many models it offers.
    func testAction() async {
        guard draft.ollamaURL != nil else {
            viewModel.connectionCheck = .failed(message: Strings.invalidAddress)
            return
        }
        viewModel.connectionCheck = .checking
        do {
            viewModel.connectionCheck = .succeeded(modelCount: try await fetchModels(draft))
        } catch {
            logger.error("Connection test failed: \(error.localizedDescription, privacy: .public)")
            viewModel.connectionCheck = .failed(message: ErrorViewConfiguration(from: error).message)
        }
    }

    /// The theme takes effect as soon as it is chosen, without waiting for Done.
    func appearanceAction() {
        let settings = settingsStore.settings
        guard settings.appearance != viewModel.appearance else {
            return
        }
        do {
            try settingsStore.update(settings.updating(appearance: viewModel.appearance))
        } catch {
            logger.error("Saving the theme failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// The lock is only switched on once the owner has shown they can open it, so no one is shut out.
    func lockAction() async {
        guard viewModel.isLockEnabled, !settingsStore.settings.isLockEnabled else {
            return
        }
        if await !authentication.authenticate(Strings.lockEnableReason) {
            viewModel.isLockEnabled = false
        }
    }

    // MARK: Memory

    var memories: [Memory] { memoryStore.memories }

    /// Adds a memory written by hand. Changes to memory take effect at once, without waiting for Done.
    func addMemoryAction() async {
        let outcome = await memoryStore.apply(.save(viewModel.newMemoryText), isFromUser: true)
        if case .saved = outcome {
            viewModel.newMemoryText = ""
        }
    }

    /// Forgets one memory, whoever wrote it.
    func deleteMemoryAction(_ id: Memory.ID) async {
        await memoryStore.apply(.delete(id), isFromUser: true)
    }

    /// Forgets everything, once the user has confirmed.
    func clearMemoriesAction() async {
        do {
            try await memoryStore.clear()
        } catch {
            logger.error("Clearing memories failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: Finishing

    /// Keeps the draft and closes the sheet. A draft that cannot be written is reported where the connection is.
    func saveAction() {
        Task { await stopVoicePreviewAction() }
        do {
            try settingsStore.update(draft)
            delegate?.settingsPresenterDidFinish(self, didSave: true)
        } catch {
            logger.error("Saving settings failed: \(error.localizedDescription, privacy: .public)")
            viewModel.connectionCheck = .failed(message: error.localizedDescription)
        }
    }

    /// Closes the sheet and lets the draft go.
    func cancelAction() {
        Task { await stopVoicePreviewAction() }
        delegate?.settingsPresenterDidFinish(self, didSave: false)
    }

    /// The settings as they stand in the form, with stray spaces trimmed. What the form does not show is carried over.
    private var draft: ServerSettings {
        ServerSettings(
            ollamaAddress: viewModel.ollamaAddress.trimmingCharacters(in: .whitespaces),
            searchAddress: viewModel.searchAddress.trimmingCharacters(in: .whitespaces),
            speechAddress: viewModel.speechAddress.trimmingCharacters(in: .whitespaces),
            voice: viewModel.voice.trimmingCharacters(in: .whitespaces),
            defaultModelID: settingsStore.settings.defaultModelID,
            appearance: viewModel.appearance,
            customInstructions: viewModel.customInstructions.trimmingCharacters(in: .whitespacesAndNewlines),
            isAutoReadEnabled: viewModel.isAutoReadEnabled,
            isLockEnabled: viewModel.isLockEnabled,
            isFollowUpsEnabled: viewModel.isFollowUpsEnabled,
            thinkingLevel: settingsStore.settings.thinkingLevel,
            isPageReadingEnabled: viewModel.isPageReadingEnabled,
            isMemoryEnabled: viewModel.isMemoryEnabled
        )
    }
}
