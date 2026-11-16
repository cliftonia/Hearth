import Foundation
import HearthCore
import HearthDomain
import os

/// What the settings tell the coordinator: that the sheet should close, that the chat server changed, and that
/// everything was erased.
@MainActor
protocol SettingsPresenterDelegate: AnyObject {
    func settingsPresenterDidFinish(_ presenter: SettingsPresenter)
    /// The chat server's address was changed and kept, so the models are to be fetched afresh.
    func settingsPresenterDidChangeChatServer(_ presenter: SettingsPresenter)
    /// Everything on the device has been erased; the app is to start again as on first launch.
    func settingsPresenterDidErase(_ presenter: SettingsPresenter)
}

/// Runs the settings, which keep every change as it is made, as the system's Settings app does.
///
/// A switch or a choice is kept at once. Typed text (the names, the instructions, a voice's name and the server
/// addresses) is kept when its field is left, when its page closes and when the settings close, so that typing is
/// never lost and nothing is written for each letter. A new server address is acted on, by fetching the models,
/// the voices or what the picture server can do, only once it has been typed. Three things are kept their own way:
/// the lock, which is only turned on once the owner has shown they can open it, the notification switches, which
/// may ask the system for permission, and the sync page, which is in `+Sync`. The work is spread over `+Servers`,
/// `+Status`, `+Profile`, `+Notifications` and `+Sync`.
@MainActor
final class SettingsPresenter {
    /// What the settings are built from.
    struct Dependencies {
        let settingsStore: SettingsStore
        let memoryStore: MemoryStore
        let profileStore: ProfileStore
        /// The models the chat server offers, and whether it was reached, for the Servers row.
        let modelStore: ModelStore
        let speech: SpeechInteractor
        let image: ImageInteractor
        let eraser: EraseInteractor
        let authentication: AuthenticationProvider
        let notifications: NotificationProvider
        /// Counts the models the given settings can reach, without changing any shared state.
        let fetchModels: @Sendable (ServerSettings) async throws -> Int
        /// Stops whatever the chat is doing, so that nothing is written while everything is being erased.
        let quietChat: @MainActor () async -> Void
        /// The sync page's store and actions.
        let sync: SyncControls
        /// Says something to VoiceOver, such as how a connection test went.
        let announce: @MainActor (String) -> Void
        /// The time now, against which "synced 2 min ago" is said.
        let now: @MainActor () -> Date
    }

    let viewModel = SettingsViewModel()
    weak var delegate: (any SettingsPresenterDelegate)?

    let dependencies: Dependencies
    let logger = Logger(for: SettingsPresenter.self)
    var previewTask: Task<Void, Never>?
    /// The server addresses as last acted on, so that a change is noticed once, whenever it is kept.
    var actedOnAddresses = ServerAddresses()

    var settingsStore: SettingsStore { dependencies.settingsStore }
    private var memoryStore: MemoryStore { dependencies.memoryStore }

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    // MARK: Loading

    /// Fills the screen from the saved settings each time the sheet opens, and asks the speech and picture servers
    /// what they offer.
    func loadAction() async {
        fillFromSaved()
        await loadProfilePhoto()
        await loadVoicesAction()
        await loadImageModelsAction()
    }

    /// Sets every control to what is saved.
    func fillFromSaved() {
        let settings = settingsStore.settings
        viewModel.ollamaAddress = settings.ollamaAddress
        viewModel.searchAddress = settings.searchAddress
        viewModel.speechAddress = settings.speechAddress
        viewModel.imageAddress = settings.imageAddress
        viewModel.imageModel = settings.imageModel
        viewModel.fullName = settings.fullName
        viewModel.nickname = settings.nickname
        viewModel.isHapticsEnabled = settings.isHapticsEnabled
        viewModel.isReplyNotificationsEnabled = settings.isReplyNotificationsEnabled
        viewModel.isTaskNotificationsEnabled = settings.isTaskNotificationsEnabled
        viewModel.profileError = nil
        viewModel.eraseError = nil
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
        viewModel.unlockWording = UnlockWording(biometry: dependencies.authentication.biometry())
        actedOnAddresses = ServerAddresses(settings)
        loadSyncAction()
    }

    // MARK: Keeping

    /// Keeps the settings as they stand on screen. Called for every switch and choice, and as typing ends.
    func keepAction() {
        write(settings(isLockEnabled: settingsStore.settings.isLockEnabled))
    }

    /// The lock is only switched on once the owner has shown they can open it, so no one is shut out. Switching
    /// it off is kept at once.
    func lockAction() async {
        let isWanted = viewModel.isLockEnabled
        guard isWanted != settingsStore.settings.isLockEnabled else {
            return
        }
        if isWanted, await !dependencies.authentication.authenticate(viewModel.unlockWording.enableReason) {
            viewModel.isLockEnabled = false
            return
        }
        write(settings(isLockEnabled: isWanted))
    }

    /// Writes the settings if they changed. One that cannot be written is said where the connection test is.
    private func write(_ settings: ServerSettings) {
        guard settings != settingsStore.settings else {
            return
        }
        do {
            try settingsStore.update(settings)
        } catch {
            logger.error("Saving settings failed: \(error.localizedDescription, privacy: .public)")
            viewModel.connectionCheck = .failed(message: error.localizedDescription)
        }
    }

    // MARK: Memory

    var memories: [Memory] { memoryStore.memories }

    /// Adds a memory written by hand.
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

    // MARK: Closing

    /// Keeps what was being typed and asks for the sheet to close.
    func closeAction() async {
        await finishEditingAction()
        delegate?.settingsPresenterDidFinish(self)
    }

    /// The sheet has gone, by Close or by a swipe: what was being typed is kept, the voice sample stops, and the
    /// next opening starts on the main list.
    func sheetDidDismissAction() async {
        await finishEditingAction()
        await stopVoicePreviewAction()
        viewModel.path = []
    }

    /// Keeps what was being typed and acts on any server address that changed.
    func finishEditingAction() async {
        keepAction()
        await serverAddressesEditedAction()
    }

    /// The settings as they stand on screen, with stray spaces trimmed. What the screen does not show is carried
    /// over from what is saved, and so are the notification switches, which their own actions keep.
    func settings(isLockEnabled: Bool) -> ServerSettings {
        let saved = settingsStore.settings
        return ServerSettings(
            ollamaAddress: viewModel.ollamaAddress.trimmingCharacters(in: .whitespaces),
            searchAddress: viewModel.searchAddress.trimmingCharacters(in: .whitespaces),
            speechAddress: viewModel.speechAddress.trimmingCharacters(in: .whitespaces),
            imageAddress: viewModel.imageAddress.trimmingCharacters(in: .whitespaces),
            imageModel: viewModel.imageModel,
            fullName: viewModel.profile.fullName,
            nickname: viewModel.profile.nickname,
            voice: viewModel.voice.trimmingCharacters(in: .whitespaces),
            defaultModelID: saved.defaultModelID,
            appearance: viewModel.appearance,
            customInstructions: viewModel.customInstructions.trimmingCharacters(in: .whitespacesAndNewlines),
            isAutoReadEnabled: viewModel.isAutoReadEnabled,
            isLockEnabled: isLockEnabled,
            isFollowUpsEnabled: viewModel.isFollowUpsEnabled,
            thinkingLevel: saved.thinkingLevel,
            isPageReadingEnabled: viewModel.isPageReadingEnabled,
            isMemoryEnabled: viewModel.isMemoryEnabled,
            isHapticsEnabled: viewModel.isHapticsEnabled,
            isReplyNotificationsEnabled: saved.isReplyNotificationsEnabled,
            isTaskNotificationsEnabled: saved.isTaskNotificationsEnabled
        )
    }

    /// The settings as they stand on screen, for asking the servers before anything is kept.
    var draft: ServerSettings { settings(isLockEnabled: settingsStore.settings.isLockEnabled) }
}
