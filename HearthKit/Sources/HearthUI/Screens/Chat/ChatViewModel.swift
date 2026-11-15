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
    /// How far a press on the resting composer has got towards recording, and what it has heard.
    var holdToTalk = HoldToTalk()
    /// How loud the voice is while the composer is held, from 0 to 1.
    var voiceLevel = 0.0
    /// Counts the times holding to talk has left words in the draft. The composer takes the keyboard on each.
    var dictatedDraftCount = 0
    /// Counts the times the chat has been handed back to the user, as when the canvas closes. VoiceOver goes to
    /// the message field on each.
    var focusRequestCount = 0
    /// Whether the sheet for choosing a model, and how hard it thinks, is showing.
    var isModelPickerPresented = false
    /// Whether the alert for renaming the open chat is showing, and the title being typed into it.
    var isRenamingChat = false
    var chatTitleDraft = ""
    /// Whether what is sent asks for a picture, not for a reply from the chat model.
    var isPictureMode = false
    /// Whether deep research is chosen as the effort for this chat, so that what is sent is researched on the web.
    /// It belongs to the open chat alone: it is not saved, and a new or another chat starts without it.
    var isResearchMode = false
    /// The picture models the server offers, for the menu at the top while pictures are being made. Empty until it answers.
    var pictureModels: [ImageModelKind] = []

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
    /// What the picture server is doing right now, while a picture is on its way.
    var pictureStatus: String?
    /// What research is doing right now, while a report is on its way.
    var researchStatus: String?
    /// What was just remembered, changed or forgotten, shown under the latest reply.
    var memoryNotice: String?
    /// Questions suggested under the latest reply.
    var followUps: [String] = []
}
