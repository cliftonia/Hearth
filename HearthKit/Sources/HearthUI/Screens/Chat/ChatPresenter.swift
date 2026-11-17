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
    /// A project is to be chosen for the chat.
    func chatPresenter(_ presenter: ChatPresenter, didRequestProjectFor id: Conversation.ID)
    /// A piece of a reply is to be opened in the canvas.
    func chatPresenter(_ presenter: ChatPresenter, didRequestCanvasFor reference: CanvasReference)
    /// A scheduled task is to be made, asking what is being written in the composer.
    func chatPresenter(_ presenter: ChatPresenter, didRequestTaskWith prompt: String)
    /// A new project is to be made.
    func chatPresenterDidRequestNewProject(_ presenter: ChatPresenter)
}

/// Runs the chat screen: sends messages, streams replies, and keeps the open conversation saved.
///
/// The work is spread over extensions by subject: `+Replying`, `+Pictures`, `+Research`, `+Editing`, `+FollowUps`, `+Menu`, `+Greeting`, `+Canvas`,
/// `+Notifications`, `+Sync` and `+Voice`.
@MainActor
final class ChatPresenter {
    /// What the chat is built from: the interactors, the dictation provider and the stores it shares with other screens.
    struct Dependencies {
        let chat: ChatInteractor
        let speech: SpeechInteractor
        let image: ImageInteractor
        let research: ResearchInteractor
        let dictation: DictationProvider
        let notifications: NotificationProvider
        let settingsStore: SettingsStore
        let modelStore: ModelStore
        let conversationStore: ConversationStore
        let memoryStore: MemoryStore
        let projectStore: ProjectStore
        /// Whether the app is locked, in which case nothing is read aloud.
        let isLocked: @MainActor () -> Bool
        /// Whether the app is in front of the user at this moment, in which case a finished reply needs no notification.
        let isOnScreen: @MainActor () -> Bool
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
    /// Told once the saved chats, projects and memories have been read, which is when sync may begin.
    var onStoresLoaded: (@MainActor () -> Void)?

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

    /// Reads the saved conversations, projects and memories, then asks the server for its models. Run as the chat appears.
    func loadAction() async {
        do {
            try await dependencies.conversationStore.load()
        } catch {
            logger.error("Loading conversations failed: \(error.localizedDescription, privacy: .public)")
        }
        do {
            try await dependencies.projectStore.load()
        } catch {
            logger.error("Loading projects failed: \(error.localizedDescription, privacy: .public)")
        }
        do {
            try await dependencies.memoryStore.load()
        } catch {
            logger.error("Loading memories failed: \(error.localizedDescription, privacy: .public)")
        }
        onStoresLoaded?()
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
        } else if isResearchChosen, !text.isEmpty {
            await submitResearch(message)
        } else {
            await submit(message)
        }
    }

    /// Sends words that were not written in the composer, as a voice conversation does, with any pictures taken
    /// as they were spoken. `onDelta` receives each piece of reply text as it arrives.
    func submit(text: String, imagesJPEG: [Data] = [], style: ReplyStyle, onDelta: @escaping @MainActor (String) -> Void) async {
        await submit(Message(role: .user, text: text, imagesJPEG: imagesJPEG), style: style, onDelta: onDelta)
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
            title: isFirstMessage ? Conversation.provisionalTitle(from: text) : nil,
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
        // A report is researched again, not answered from what the model already knows.
        if previous?.isResearch == true || (previous == nil && isResearchChosen) {
            await research(model: model, replacing: previous)
            return
        }
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
    ///
    /// - Parameter projectID: The project the new chat belongs to; `nil` for an ordinary chat.
    func newChatAction(in projectID: Project.ID? = nil) async {
        await show(Conversation(modelID: viewModel.selectedModel?.id, projectID: projectID))
    }

    /// Opens a saved conversation, and switches to the model it was held with if the server still offers it.
    func selectConversationAction(_ id: Conversation.ID) async {
        guard id != viewModel.conversation.id, let conversation = dependencies.conversationStore.conversation(for: id) else {
            return
        }
        await show(conversation)
        if let model = dependencies.modelStore.model(for: conversation.modelID) {
            viewModel.selectedModel = model
        }
    }

    /// Stops whatever is under way, clears what belonged to the conversation on screen, and shows the given one.
    private func show(_ conversation: Conversation) async {
        await stopAction()
        await stopSpeaking()
        cancelEditAction()
        viewModel.followUps = []
        viewModel.memoryNotice = nil
        viewModel.isResearchMode = false
        viewModel.conversation = conversation
        viewModel.error = nil
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
