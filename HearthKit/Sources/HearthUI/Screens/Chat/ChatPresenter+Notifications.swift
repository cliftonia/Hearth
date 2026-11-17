import Foundation
import HearthDomain

// Telling the user that a reply finished while they were elsewhere, and what follows from their tapping that.
extension ChatPresenter {
    /// Posts a notification for a reply that has just finished, when the user has asked for them and the app is
    /// not in front of them. A turn that failed or came to nothing is not announced.
    func notifyReplyFinished(_ replyID: Message.ID) async {
        let conversation = viewModel.conversation
        guard viewModel.error == nil, let reply = conversation.messages.first(where: { $0.id == replyID }) else {
            return
        }
        let notice = ReplyNotificationPlanner().notice(
            for: reply,
            in: conversation,
            isEnabled: settings.isReplyNotificationsEnabled,
            isOnScreen: dependencies.isOnScreen()
        )
        guard let notice else {
            return
        }
        do {
            try await dependencies.notifications.post(Self.notification(for: notice, conversationID: conversation.id))
        } catch {
            // Most often the system's permission has been withdrawn, which the Notifications page already says.
            logger.notice("A reply notification was not posted: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Tells someone using VoiceOver that a reply has finished and is there to be read. Said only while VoiceOver is
    /// running and the app is on screen, and not for a turn that failed or came to nothing.
    func announceReplyFinished(_ replyID: Message.ID) {
        guard dependencies.isVoiceOverRunning(), dependencies.isOnScreen(), viewModel.error == nil,
              viewModel.conversation.messages.contains(where: { $0.id == replyID }) else {
            return
        }
        dependencies.announce(Strings.replyFinished)
    }

    /// The words of a notification. A private chat's says only that a reply is ready, under the app's own name.
    static func notification(for notice: ReplyNoticeKind, conversationID: Conversation.ID) -> ReplyNotification {
        switch notice {
        case .text(let title, let excerpt):
            ReplyNotification(conversationID: conversationID, title: title.isEmpty ? Strings.brand : title, body: excerpt)
        case .picture(let title):
            ReplyNotification(conversationID: conversationID, title: title.isEmpty ? Strings.brand : title, body: Strings.notificationPictureReady)
        case .discreet:
            ReplyNotification(conversationID: conversationID, title: Strings.brand, body: Strings.notificationReplyReady)
        }
    }

    /// Opens the chat a tapped notification was about. A tap may be what launched the app, before the chats
    /// have been read from disk, so they are read first if the chat is not yet known.
    func openNotifiedConversationAction(_ id: Conversation.ID) async {
        if dependencies.conversationStore.conversation(for: id) == nil {
            do {
                try await dependencies.conversationStore.load()
            } catch {
                logger.error("Loading conversations failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        await selectConversationAction(id)
    }

    /// Stops everything the chat is doing, ahead of everything on the device being erased.
    func quietAction() async {
        await stopAction()
        await stopSpeaking()
        await stopDictation()
    }

    /// Starts again as on first launch, once everything has been erased: an empty chat, no model carried over,
    /// and the models of whichever server the app was built to start with.
    func resetAction() async {
        viewModel.selectedModel = nil
        viewModel.isPictureMode = false
        viewModel.isResearchMode = false
        viewModel.pictureModels = []
        await newChatAction()
        composerDrafts = [:]
        await refreshModelsAction()
    }
}
