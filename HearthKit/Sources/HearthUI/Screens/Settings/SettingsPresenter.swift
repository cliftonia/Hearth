import Foundation
import HearthCore
import HearthDomain
import Observation
import os

@MainActor
protocol SettingsPresenterDelegate: AnyObject {
    func settingsPresenterDidFinish(_ presenter: SettingsPresenter, didSave: Bool)
}

enum ConnectionCheckKind: Hashable {
    case idle
    case checking
    case succeeded(modelCount: Int)
    case failed(message: String)
}

@MainActor
@Observable
final class SettingsViewModel {
    var ollamaAddress = ""
    var searchAddress = ""
    var speechAddress = ""
    var voice = ServerSettings.defaultVoice
    var voices: [String] = []
    var appearance: AppearanceKind = .system
    var customInstructions = ""
    var isAutoReadEnabled = false
    var isLockEnabled = false
    var isFollowUpsEnabled = true
    var isPageReadingEnabled = true
    var isMemoryEnabled = true
    var newMemoryText = ""
    var isConfirmingClearMemories = false
    var connectionCheck: ConnectionCheckKind = .idle
}

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
        await loadVoicesAction()
    }

    /// The list of voices is a convenience; without it the voice is typed by name.
    func loadVoicesAction() async {
        viewModel.voices = (try? await speech.voices(settings: draft)) ?? []
    }

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

    func deleteMemoryAction(_ id: Memory.ID) async {
        await memoryStore.apply(.delete(id), isFromUser: true)
    }

    func clearMemoriesAction() async {
        do {
            try await memoryStore.clear()
        } catch {
            logger.error("Clearing memories failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func saveAction() {
        do {
            try settingsStore.update(draft)
            delegate?.settingsPresenterDidFinish(self, didSave: true)
        } catch {
            logger.error("Saving settings failed: \(error.localizedDescription, privacy: .public)")
            viewModel.connectionCheck = .failed(message: error.localizedDescription)
        }
    }

    func cancelAction() {
        delegate?.settingsPresenterDidFinish(self, didSave: false)
    }

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
