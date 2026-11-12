import Foundation
import HearthDomain

// Streaming a reply into the conversation, saving it, and what follows from a finished turn.
extension ChatPresenter {
    /// Adds an empty reply to the conversation and fills it as the model answers. Returns once the turn is over,
    /// whether it finished, failed or was stopped, with what arrived saved.
    func reply(model: ChatModel, style: ReplyStyle, onDelta: (@MainActor (String) -> Void)?) async {
        let reply = Message(role: .assistant, text: "")
        let usesMemory = settings.allowsMemory(in: viewModel.conversation)
        let turn = ChatInteractor.Turn(
            history: viewModel.conversation.messages,
            model: model,
            settings: settings,
            searchMode: searchMode(for: model),
            style: style,
            memories: usesMemory ? dependencies.memoryStore.memories : [],
            remember: usesMemory ? rememberClosure : nil,
            isPrivate: viewModel.conversation.isPrivate
        )
        viewModel.conversation = viewModel.conversation.updating(messages: viewModel.conversation.messages + [reply], updatedAt: Date())
        viewModel.error = nil
        viewModel.followUps = []
        viewModel.memoryNotice = nil
        viewModel.isStreaming = true
        let events = dependencies.chat.run(turn)
        // A reply should outlive a glance at another app, for as long as iOS allows.
        backgroundActivity.begin(named: "Reply")
        await stopSpeaking()
        let narration = style == .chat ? beginNarration(of: reply.id) : nil
        let task = Task {
            await self.consume(events, replyID: reply.id) { delta in
                onDelta?(delta)
                narration?.append(delta)
            }
            narration?.finish()
            self.viewModel.isStreaming = false
            self.viewModel.searchingQuery = nil
            await self.save(self.discardingEmptyReply(reply.id))
        }
        turnTask = task
        await task.value
        backgroundActivity.end()
    }

    /// Applies each event of the turn to the reply, and turns a failure into an error the user can read.
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
            // A connection lost while the app was off screen is iOS suspending it, not the server or the VPN.
            viewModel.error = backgroundActivity.wasBackgrounded
                ? ErrorViewConfiguration(title: Strings.interruptedTitle, message: Strings.interruptedMessage)
                : ErrorViewConfiguration(from: error)
        }
    }

    /// Folds one event into the reply or into the view model's passing state.
    func apply(_ event: ChatInteractor.Event, to replyID: Message.ID, startedAt: Date) {
        guard let message = viewModel.conversation.messages.first(where: { $0.id == replyID }) else {
            return
        }
        let updated: Message
        switch event {
        case .searching(let query):
            viewModel.searchingQuery = query
            return
        case .sources(let sources):
            viewModel.searchingQuery = nil
            updated = message.updating(sources: sources)
        case .memory(let outcome):
            viewModel.memoryNotice = Self.notice(for: outcome) ?? viewModel.memoryNotice
            return
        case .searchFailed:
            viewModel.searchingQuery = nil
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

    /// Writes the conversation to disk, telling the user if it could not be.
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

    /// Keeps the chosen model if the server still offers it; otherwise falls back to the conversation's model,
    /// then the one last chosen, then the first on offer.
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
