import Foundation
import HearthDomain

// Suggested follow-up questions, and the switch that reads every reply aloud.
extension ChatPresenter {
    var isAutoReadEnabled: Bool { settings.isAutoReadEnabled }

    /// Turns reading every reply aloud on or off. Turning it off also silences a reply being read.
    func toggleAutoReadAction() async {
        let isEnabled = !settings.isAutoReadEnabled
        do {
            try dependencies.settingsStore.update(settings.updating(isAutoReadEnabled: isEnabled))
        } catch {
            logger.error("Saving the read-aloud switch failed: \(error.localizedDescription, privacy: .public)")
        }
        if !isEnabled {
            await stopSpeaking()
        }
    }

    /// Sends a suggested question as the user's next message.
    func followUpAction(_ question: String) async {
        guard !viewModel.isStreaming else {
            return
        }
        await submit(Message(role: .user, text: question))
    }

    /// Asks the model what the user might ask next. Suggestions are a nicety: without them the chat is complete.
    func suggestFollowUps(model: ChatModel) async {
        guard settings.isFollowUpsEnabled, let reply = viewModel.conversation.messages.last, reply.role == .assistant else {
            return
        }
        let conversationID = viewModel.conversation.id
        let questions = (try? await dependencies.chat.followUps(history: viewModel.conversation.messages, model: model, settings: settings)) ?? []
        // The user may have moved on while the model was thinking of questions.
        let isCurrent = viewModel.conversation.id == conversationID && viewModel.conversation.messages.last?.id == reply.id
        if isCurrent, !viewModel.isStreaming {
            viewModel.followUps = questions
        }
    }
}
