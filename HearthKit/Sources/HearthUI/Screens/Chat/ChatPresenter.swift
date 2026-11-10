import Foundation
import HearthCore
import HearthDomain
import os

@MainActor
protocol ChatPresenterDelegate: AnyObject {
    func chatPresenterDidRequestSidebar(_ presenter: ChatPresenter)
    func chatPresenterDidRequestVoice(_ presenter: ChatPresenter)
    func chatPresenterDidRequestSettings(_ presenter: ChatPresenter)
}

@MainActor
final class ChatPresenter {
    struct Dependencies {
        let chat: ChatInteractor
        let speech: SpeechInteractor
        let dictation: DictationProvider
        let settingsStore: SettingsStore
        let modelStore: ModelStore
        let conversationStore: ConversationStore
    }

    let viewModel = ChatViewModel()
    weak var delegate: (any ChatPresenterDelegate)?

    let dependencies: Dependencies
    let logger = Logger(for: ChatPresenter.self)
    var dictationTask: Task<Void, Never>?
    var speakTask: Task<Void, Never>?
    private var turnTask: Task<Void, Never>?

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    var settings: ServerSettings { dependencies.settingsStore.settings }
    var models: [ChatModel] { dependencies.modelStore.models }
    var isServerConfigured: Bool { settings.ollamaURL != nil }
    var isSearchAvailable: Bool { settings.searchURL != nil }
    var isSpeechAvailable: Bool { settings.speechURL != nil }

    // MARK: Loading

    func loadAction() async {
        do {
            try await dependencies.conversationStore.load()
        } catch {
            logger.error("Loading conversations failed: \(error.localizedDescription, privacy: .public)")
        }
        await refreshModelsAction()
    }

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

    func sendAction() async {
        guard viewModel.canSend, !viewModel.isStreaming else {
            return
        }
        let text = viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines)
        let images = viewModel.pendingImagesJPEG
        viewModel.draft = ""
        viewModel.pendingImagesJPEG = []
        await submit(text: text, imagesJPEG: images)
    }

    /// Adds the user's message and streams the reply. `onDelta` receives each piece of reply text as it arrives.
    func submit(text: String, imagesJPEG: [Data] = [], style: ReplyStyle = .chat, onDelta: (@MainActor (String) -> Void)? = nil) async {
        guard let model = viewModel.selectedModel else {
            viewModel.error = ErrorViewConfiguration(from: ChatError.noModelSelected)
            return
        }
        await stopDictation()
        let conversation = viewModel.conversation
        let isFirstMessage = conversation.messages.isEmpty
        viewModel.conversation = conversation.updating(
            title: isFirstMessage ? String(text.prefix(48)) : nil,
            modelID: model.id,
            messages: conversation.messages + [Message(role: .user, text: text, imagesJPEG: imagesJPEG)]
        )
        await reply(model: model, style: style, onDelta: onDelta)
        if isFirstMessage {
            await nameConversation(conversation.id, from: text, model: model)
        }
    }

    func stopAction() async {
        turnTask?.cancel()
        await turnTask?.value
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

    func regenerateAction() async {
        guard !viewModel.isStreaming, let model = viewModel.selectedModel else {
            return
        }
        var messages = viewModel.conversation.messages
        if messages.last?.role == .assistant {
            messages.removeLast()
        }
        guard messages.last?.role == .user else {
            return
        }
        viewModel.conversation = viewModel.conversation.updating(messages: messages)
        await reply(model: model, style: .chat, onDelta: nil)
    }

    func newChatAction() async {
        await stopAction()
        await stopSpeaking()
        viewModel.conversation = Conversation(modelID: viewModel.selectedModel?.id)
        viewModel.error = nil
    }

    func selectConversationAction(_ id: Conversation.ID) async {
        guard id != viewModel.conversation.id, let conversation = dependencies.conversationStore.conversation(for: id) else {
            return
        }
        await stopAction()
        await stopSpeaking()
        viewModel.conversation = conversation
        viewModel.error = nil
        if let model = dependencies.modelStore.model(for: conversation.modelID) {
            viewModel.selectedModel = model
        }
    }

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

// MARK: - Replying

private extension ChatPresenter {
    func reply(model: ChatModel, style: ReplyStyle, onDelta: (@MainActor (String) -> Void)?) async {
        let reply = Message(role: .assistant, text: "")
        let turn = ChatInteractor.Turn(
            history: viewModel.conversation.messages,
            model: model,
            settings: settings,
            isSearchEnabled: viewModel.isSearchEnabled && isSearchAvailable,
            style: style
        )
        viewModel.conversation = viewModel.conversation.updating(messages: viewModel.conversation.messages + [reply], updatedAt: Date())
        viewModel.error = nil
        viewModel.isStreaming = true
        let events = dependencies.chat.run(turn)
        let task = Task {
            await self.consume(events, replyID: reply.id, onDelta: onDelta)
            self.viewModel.isStreaming = false
            await self.save(self.discardingEmptyReply(reply.id))
        }
        turnTask = task
        await task.value
    }

    func consume(_ events: AsyncThrowingStream<ChatInteractor.Event, any Error>, replyID: Message.ID, onDelta: (@MainActor (String) -> Void)?) async {
        let startedAt = Date()
        do {
            for try await event in events {
                apply(event, to: replyID, startedAt: startedAt)
                if case .text(let delta) = event {
                    onDelta?(delta)
                }
            }
        } catch is CancellationError {
            // Stopped by the user; what has arrived so far is kept.
        } catch {
            logger.error("Reply failed: \(error.localizedDescription, privacy: .public)")
            viewModel.error = ErrorViewConfiguration(from: error)
        }
    }

    func apply(_ event: ChatInteractor.Event, to replyID: Message.ID, startedAt: Date) {
        guard let message = viewModel.conversation.messages.first(where: { $0.id == replyID }) else {
            return
        }
        let updated: Message
        switch event {
        case .sources(let sources):
            updated = message.updating(sources: sources)
        case .searchFailed:
            viewModel.error = ErrorViewConfiguration(title: Strings.searchLabel, message: Strings.searchFailed, retryActionLabel: nil)
            return
        case .thinking(let delta):
            updated = message.updating(thinking: message.thinking + delta)
        case .text(let delta):
            let isFirstText = message.text.isEmpty && !message.thinking.isEmpty
            updated = message.updating(
                text: message.text + delta,
                thinkingSeconds: isFirstText ? Int(Date().timeIntervalSince(startedAt).rounded()) : nil
            )
        }
        viewModel.conversation = viewModel.conversation.replacing(updated)
    }

    /// A reply that never produced anything is removed rather than left as an empty row.
    func discardingEmptyReply(_ replyID: Message.ID) -> Conversation {
        let conversation = viewModel.conversation
        guard let reply = conversation.messages.first(where: { $0.id == replyID }), reply.text.isEmpty, reply.thinking.isEmpty else {
            return conversation
        }
        let trimmed = conversation.updating(messages: conversation.messages.filter { $0.id != replyID })
        viewModel.conversation = trimmed
        return trimmed
    }

    func save(_ conversation: Conversation) async {
        do {
            try await dependencies.conversationStore.save(conversation)
        } catch {
            logger.error("Saving the conversation failed: \(error.localizedDescription, privacy: .public)")
            viewModel.error = ErrorViewConfiguration(message: Strings.errorSaveFailed, retryActionLabel: nil)
        }
    }

    /// Asks the model for a short title. The first words of the message stay as the title if it cannot.
    func nameConversation(_ id: Conversation.ID, from text: String, model: ChatModel) async {
        guard let title = try? await dependencies.chat.title(for: text, model: model, settings: settings), !title.isEmpty,
              let stored = dependencies.conversationStore.conversation(for: id) else {
            return
        }
        if viewModel.conversation.id == id {
            viewModel.conversation = viewModel.conversation.updating(title: title)
        }
        await save(stored.updating(title: title))
    }

    func selectAvailableModel() {
        if let selected = viewModel.selectedModel, models.contains(selected) {
            return
        }
        let store = dependencies.modelStore
        viewModel.selectedModel = store.model(for: viewModel.conversation.modelID)
            ?? store.model(for: settings.defaultModelID)
            ?? models.first
    }
}
