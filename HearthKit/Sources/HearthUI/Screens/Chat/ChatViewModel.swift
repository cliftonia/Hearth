import Foundation
import HearthDomain
import Observation

/// What the chat screen shows: the open conversation, the message being written, and what is under way.
@MainActor
@Observable
final class ChatViewModel {
    // MARK: Conversation

    var conversation = Conversation()
    var selectedModel: ChatModel?

    // MARK: Composer

    /// The message being written.
    var draft = ""
    /// Photos and files attached to the message being written.
    var pendingImagesJPEG: [Data] = []
    var pendingDocuments: [AttachedDocument] = []
    /// The sent message now back in the composer, if one is being edited.
    var editingMessageID: Message.ID?
    /// The search toggle, for models that cannot ask for a search themselves.
    var isSearchEnabled = false
    var isDictating = false

    /// Whether there is anything to send: words, a photo or a file.
    var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !pendingImagesJPEG.isEmpty || !pendingDocuments.isEmpty
    }

    // MARK: Reply

    /// A reply is on its way.
    var isStreaming = false
    /// The reply being read aloud, if one is.
    var speakingMessageID: Message.ID?
    var error: ErrorViewConfiguration?
    /// What the web is being searched for right now, while a reply is on its way.
    var searchingQuery: String?
    /// What was just remembered, changed or forgotten, shown under the latest reply.
    var memoryNotice: String?
    /// Questions suggested under the latest reply.
    var followUps: [String] = []
}
