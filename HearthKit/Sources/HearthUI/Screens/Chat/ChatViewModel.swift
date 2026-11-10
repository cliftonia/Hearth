import Foundation
import HearthDomain
import Observation

@MainActor
@Observable
final class ChatViewModel {
    var conversation = Conversation()
    var draft = ""
    var pendingImagesJPEG: [Data] = []
    var pendingDocuments: [AttachedDocument] = []
    /// The sent message now back in the composer, if one is being edited.
    var editingMessageID: Message.ID?
    var selectedModel: ChatModel?
    var isSearchEnabled = false
    var isStreaming = false
    var isDictating = false
    var speakingMessageID: Message.ID?
    var error: ErrorViewConfiguration?
    /// Questions suggested under the latest reply.
    var followUps: [String] = []

    var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !pendingImagesJPEG.isEmpty || !pendingDocuments.isEmpty
    }
}
