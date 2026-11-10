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
    var connectionCheck: ConnectionCheckKind = .idle
}

@MainActor
final class SettingsPresenter {
    let viewModel = SettingsViewModel()
    weak var delegate: (any SettingsPresenterDelegate)?

    private let settingsStore: SettingsStore
    private let speech: SpeechInteractor
    private let fetchModels: @Sendable (ServerSettings) async throws -> Int
    private let logger = Logger(for: SettingsPresenter.self)

    /// - Parameter fetchModels: Counts the models the given settings can reach, without changing any shared state.
    init(settingsStore: SettingsStore, speech: SpeechInteractor, fetchModels: @escaping @Sendable (ServerSettings) async throws -> Int) {
        self.settingsStore = settingsStore
        self.speech = speech
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
            customInstructions: viewModel.customInstructions.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}
