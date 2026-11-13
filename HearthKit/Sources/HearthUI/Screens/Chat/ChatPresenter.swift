import Foundation
import HearthCore
import HearthDomain
import os

/// What the chat asks of the coordinator: the screens that open over or beside it.
@MainActor
protocol ChatPresenterDelegate: AnyObject {
    func chatPresenterDidRequestSidebar(_ presenter: ChatPresenter)
    func chatPresenterDidRequestVoice(_ presenter: ChatPresenter)
    func chatPresenterDidRequestSettings(_ presenter: ChatPresenter)
}

/// Runs the chat screen: sends messages, streams replies, and keeps the open conversation saved.
///
/// The work is spread over extensions by subject: `+Replying`, `+Pictures`, `+Editing`, `+FollowUps` and `+Voice`.
@MainActor
final class ChatPresenter {
    /// What the chat is built from: the interactors, the dictation provider and the stores it shares with other screens.
    struct Dependencies {
        let chat: ChatInteractor
        let speech: SpeechInteractor
        let image: ImageInteractor
        let dictation: DictationProvider
        let settingsStore: SettingsStore
        let modelStore: ModelStore
        let conversationStore: ConversationStore
        let memoryStore: MemoryStore
        /// Whether the app is locked, in which case nothing is read aloud.
        let isLocked: @MainActor () -> Bool
    }

    let viewModel = ChatViewModel()
    weak var delegate: (any ChatPresenterDelegate)?

    let dependencies: Dependencies
    let logger = Logger(for: ChatPresenter.self)
    let backgroundActivity = BackgroundActivity()
    /// Copies what is dictated into the draft until dictation ends.
    var dictationTask: Task<Void, Never>?
    /// The reply being read aloud, kept so that it can be silenced.
    var speakTask: Task<Void, Never>?
    /// The reply being streamed, kept so that it can be stopped.
    var turnTask: Task<Void, Never>?

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    // MARK: Shared state

    var settings: ServerSettings { dependencies.settingsStore.settings }
    var models: [ChatModel] { dependencies.modelStore.models }
    var isServerConfigured: Bool { settings.ollamaURL != nil }
    var isSearchAvailable: Bool { settings.searchURL != nil }
    var isSpeechAvailable: Bool { settings.speechURL != nil }
    var isPictureAvailable: Bool { settings.imageURL != nil }

    // MARK: Loading

    /// Reads the saved conversations and memories, then asks the server for its models. Run as the chat appears.
    func loadAction() async {
        do {
            try await dependencies.conversationStore.load()
        } catch {
            logger.error("Loading conversations failed: \(error.localizedDescription, privacy: .public)")
        }
        do {
            try await dependencies.memoryStore.load()
        } catch {
            logger.error("Loading memories failed: \(error.localizedDescription, privacy: .public)")
        }
        await refreshModelsAction()
    }

    /// Fetches the server's models again, as after the settings change, and settles which one is chosen.
    func refreshModelsAction() async {
        do {
            try await dependencies.modelStore.refresh(settings: settings)
            viewModel.error = nil
        } catch ChatError.serverNotConfigured {
            // The empty state invites the user to add a server; no error is shown for it.
        } catch {
            logger.error("Refreshing models failed: \(error.localizedDescription, privacy: .public)")
            viewModel.error = ErrorViewConfiguration(from: error)
        }
        selectAvailableModel()
    }

    // MARK: Conversation

    /// Sends what is in the composer. If a sent message was being edited, it and everything after it are replaced.
    func sendAction() async {
        guard viewModel.canSend, !viewModel.isStreaming else {
            return
        }
        let text = viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines)
        let message = Message(role: .user, text: text, imagesJPEG: viewModel.pendingImagesJPEG, documents: viewModel.pendingDocuments)
        discardEditedMessages()
        viewModel.draft = ""
        viewModel.pendingImagesJPEG = []
        viewModel.pendingDocuments = []
        if viewModel.isPictureMode {
            await submitPicture(message)
        } else {
            await submit(message)
        }
    }

    /// Sends words alone, as a voice conversation does. `onDelta` receives each piece of reply text as it arrives.
    func submit(text: String, style: ReplyStyle, onDelta: @escaping @MainActor (String) -> Void) async {
        await submit(Message(role: .user, text: text), style: style, onDelta: onDelta)
    }

    /// Adds the user's message and streams the reply.
    func submit(_ message: Message, style: ReplyStyle = .chat, onDelta: (@MainActor (String) -> Void)? = nil) async {
        guard let model = viewModel.selectedModel else {
            viewModel.error = ErrorViewConfiguration(from: ChatError.noModelSelected)
            return
        }
        await stopDictation()
        let conversation = viewModel.conversation
        let isFirstMessage = conversation.messages.isEmpty
        let text = message.text.isEmpty ? (message.documents.first?.name ?? "") : message.text
        viewModel.conversation = conversation.updating(
            title: isFirstMessage ? String(text.prefix(48)) : nil,
            modelID: model.id,
            messages: conversation.messages + [message]
        )
        await reply(model: model, style: style, onDelta: onDelta)
        if isFirstMessage {
            await nameConversation(conversation.id, from: text, model: model)
        }
        if style == .chat {
            await suggestFollowUps(model: model)
        }
    }

    /// Stops a reply on its way, and with it any reading of that reply aloud.
    func stopAction() async {
        guard turnTask != nil else {
            return
        }
        turnTask?.cancel()
        await turnTask?.value
        turnTask = nil
        await stopSpeaking()
    }

    /// Makes a chat that has not yet begun private, or ordinary again. A private chat neither uses nor adds to memory.
    func togglePrivateAction() {
        guard viewModel.conversation.messages.isEmpty else {
            return
        }
        viewModel.conversation = viewModel.conversation.updating(isPrivate: !viewModel.conversation.isPrivate)
    }

    /// Repeats what failed: fetching the models if there are none, otherwise the last reply.
    func retryAction() async {
        viewModel.error = nil
        guard !models.isEmpty else {
            await refreshModelsAction()
            return
        }
        await regenerateAction()
    }

    /// Asks for another reply to the same message. The last reply is kept behind the new one as an earlier version.
    func regenerateAction() async {
        guard !viewModel.isStreaming, let model = viewModel.selectedModel else {
            return
        }
        var messages = viewModel.conversation.messages
        var previous: Message?
        if messages.last?.role == .assistant {
            previous = messages.removeLast()
        }
        guard let asked = messages.last, asked.role == .user else {
            return
        }
        // A picture is asked for again from the picture server, not from the chat model.
        if previous?.isPicture == true || (previous == nil && viewModel.isPictureMode) {
            viewModel.conversation = viewModel.conversation.updating(messages: Array(messages.dropLast()))
            await submitPicture(asked)
            return
        }
        viewModel.conversation = viewModel.conversation.updating(messages: messages)
        await reply(model: model, style: .chat, replacing: previous, onDelta: nil)
        await suggestFollowUps(model: model)
    }

    /// Shows another version of a reply that was asked for more than once.
    func selectVersionAction(_ index: Int, of id: Message.ID) async {
        guard !viewModel.isStreaming, let message = viewModel.conversation.messages.first(where: { $0.id == id }) else {
            return
        }
        await stopSpeaking()
        viewModel.followUps = []
        viewModel.conversation = viewModel.conversation.replacing(message.showingVersion(index))
        await save(viewModel.conversation)
    }

    /// Stops whatever is under way and clears the screen for a fresh conversation with the same model.
    func newChatAction() async {
        await stopAction()
        await stopSpeaking()
        cancelEditAction()
        viewModel.draft = ""
        viewModel.followUps = []
        viewModel.memoryNotice = nil
        viewModel.conversation = Conversation(modelID: viewModel.selectedModel?.id)
        viewModel.error = nil
    }

    /// Opens a saved conversation, and switches to the model it was held with if the server still offers it.
    func selectConversationAction(_ id: Conversation.ID) async {
        guard id != viewModel.conversation.id, let conversation = dependencies.conversationStore.conversation(for: id) else {
            return
        }
        await stopAction()
        await stopSpeaking()
        cancelEditAction()
        viewModel.followUps = []
        viewModel.memoryNotice = nil
        viewModel.conversation = conversation
        viewModel.error = nil
        if let model = dependencies.modelStore.model(for: conversation.modelID) {
            viewModel.selectedModel = model
        }
    }

    // MARK: Composer

    /// Switches model and remembers the choice for the next launch.
    func selectModelAction(_ model: ChatModel) {
        viewModel.selectedModel = model
        do {
            try dependencies.settingsStore.update(settings.updating(defaultModelID: model.id))
        } catch {
            logger.error("Remembering the model failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func toggleSearchAction() {
        viewModel.isSearchEnabled.toggle()
    }

    func addImagesAction(_ imagesJPEG: [Data]) {
        viewModel.pendingImagesJPEG.append(contentsOf: imagesJPEG)
    }

    func removeImageAction(at index: Int) {
        guard viewModel.pendingImagesJPEG.indices.contains(index) else {
            return
        }
        viewModel.pendingImagesJPEG.remove(at: index)
    }

    // MARK: Navigation

    func sidebarAction() {
        delegate?.chatPresenterDidRequestSidebar(self)
    }

    func voiceAction() {
        delegate?.chatPresenterDidRequestVoice(self)
    }

    func settingsAction() {
        delegate?.chatPresenterDidRequestSettings(self)
    }
}
