import Foundation
import HearthDomain
import Observation

@MainActor
@Observable
final class ChatViewModel {
    var conversation = Conversation()
    var draft = ""
    var pendingImagesJPEG: [Data] = []
    var selectedModel: ChatModel?
    var isSearchEnabled = false
    var isStreaming = false
    var isDictating = false
    var speakingMessageID: Message.ID?
    var error: ErrorViewConfiguration?

    var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !pendingImagesJPEG.isEmpty
    }
}
