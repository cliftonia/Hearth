import Foundation

// Every user-facing string, resolved through `Localizable.xcstrings`.
// swiftlint:disable line_length
enum Strings {
    static let brand = String(localized: "brand", defaultValue: "Hearth", bundle: .module)

    static let menuLabel = String(localized: "chat.menu", defaultValue: "Open chat list", bundle: .module)
    static let newChat = String(localized: "chat.newChat", defaultValue: "New chat", bundle: .module)
    static let modelPickerLabel = String(localized: "chat.modelPicker", defaultValue: "Choose model", bundle: .module)
    static let noModel = String(localized: "chat.noModel", defaultValue: "No model", bundle: .module)
    static let localModels = String(localized: "chat.localModels", defaultValue: "On your server", bundle: .module)
    static let cloudModels = String(localized: "chat.cloudModels", defaultValue: "Cloud", bundle: .module)
    static let localTag = String(localized: "chat.localTag", defaultValue: "local", bundle: .module)
    static let cloudTag = String(localized: "chat.cloudTag", defaultValue: "cloud", bundle: .module)
    static let privateChat = String(localized: "chat.private", defaultValue: "Private chat", bundle: .module)
    static let privateChatNote = String(localized: "chat.privateNote", defaultValue: "This chat uses no memories and adds none.", bundle: .module)
    static let emptyTitle = String(localized: "chat.emptyTitle", defaultValue: "What shall we talk about?", bundle: .module)
    static let connectTitle = String(localized: "chat.connectTitle", defaultValue: "Connect to your server", bundle: .module)
    static let connectMessage = String(localized: "chat.connectMessage", defaultValue: "Add the address of your Ollama server to begin.", bundle: .module)
    static let openSettings = String(localized: "chat.openSettings", defaultValue: "Open Settings", bundle: .module)

    static let composerPlaceholder = String(localized: "composer.placeholder", defaultValue: "Message", bundle: .module)
    static let attach = String(localized: "composer.attach", defaultValue: "Attach", bundle: .module)
    static let chooseFile = String(localized: "composer.chooseFile", defaultValue: "Choose file", bundle: .module)
    static let takePhoto = String(localized: "composer.takePhoto", defaultValue: "Take photo", bundle: .module)
    static let photoLibrary = String(localized: "composer.photoLibrary", defaultValue: "Photo library", bundle: .module)
    static let removeFile = String(localized: "composer.removeFile", defaultValue: "Remove file", bundle: .module)
    static let filesUnreadable = String(localized: "composer.filesUnreadable", defaultValue: "Some files could not be read. PDFs and text files are supported.", bundle: .module)
    static let thinkingLevel = String(localized: "composer.thinking", defaultValue: "Thinking", bundle: .module)
    static let thinkingOff = String(localized: "composer.thinkingOff", defaultValue: "Off", bundle: .module)
    static let thinkingLight = String(localized: "composer.thinkingLight", defaultValue: "Light", bundle: .module)
    static let thinkingMedium = String(localized: "composer.thinkingMedium", defaultValue: "Medium", bundle: .module)
    static let thinkingHigh = String(localized: "composer.thinkingHigh", defaultValue: "High", bundle: .module)
    static let followUps = String(localized: "chat.followUps", defaultValue: "Suggested questions", bundle: .module)
    static let followUpHint = String(localized: "chat.followUpHint", defaultValue: "Asks this question", bundle: .module)
    static let suggestFollowUps = String(localized: "settings.followUps", defaultValue: "Suggest follow-up questions", bundle: .module)
    static let editingMessage = String(localized: "composer.editing", defaultValue: "Editing message", bundle: .module)
    static let cancelEdit = String(localized: "composer.cancelEdit", defaultValue: "Cancel editing", bundle: .module)
    static let removePhoto = String(localized: "composer.removePhoto", defaultValue: "Remove photo", bundle: .module)
    static let search = String(localized: "composer.search", defaultValue: "Search", bundle: .module)
    static let searchLabel = String(localized: "composer.searchLabel", defaultValue: "Web search", bundle: .module)
    static let dictate = String(localized: "composer.dictate", defaultValue: "Dictate", bundle: .module)
    static let stopDictation = String(localized: "composer.stopDictation", defaultValue: "Stop dictation", bundle: .module)
    static let send = String(localized: "composer.send", defaultValue: "Send", bundle: .module)
    static let stopReply = String(localized: "composer.stop", defaultValue: "Stop reply", bundle: .module)
    static let startVoice = String(localized: "composer.voice", defaultValue: "Start voice conversation", bundle: .module)

    static let copy = String(localized: "message.copy", defaultValue: "Copy", bundle: .module)
    static let edit = String(localized: "message.edit", defaultValue: "Edit", bundle: .module)
    static let share = String(localized: "message.share", defaultValue: "Share", bundle: .module)
    static let exportUser = String(localized: "export.user", defaultValue: "You", bundle: .module)
    static let readAloud = String(localized: "message.speak", defaultValue: "Read aloud", bundle: .module)
    static let stopReading = String(localized: "message.stopSpeaking", defaultValue: "Stop reading", bundle: .module)
    static let tryAgain = String(localized: "message.retry", defaultValue: "Try again", bundle: .module)
    static let thinking = String(localized: "message.thinking", defaultValue: "Thinking…", bundle: .module)
    static let thoughtBriefly = String(localized: "message.thoughtBriefly", defaultValue: "Thought briefly", bundle: .module)
    static let copyCode = String(localized: "message.copyCode", defaultValue: "Copy code", bundle: .module)
    static let code = String(localized: "message.code", defaultValue: "code", bundle: .module)
    static let attachedPhoto = String(localized: "message.attachedPhoto", defaultValue: "Attached photo", bundle: .module)
    static let writing = String(localized: "message.writing", defaultValue: "Writing a reply", bundle: .module)
    static let searchFailed = String(localized: "notice.searchFailed", defaultValue: "Web search failed, so this reply does not use it.", bundle: .module)

    static let errorTitle = String(localized: "error.title", defaultValue: "Something went wrong", bundle: .module)
    static let retry = String(localized: "error.retry", defaultValue: "Retry", bundle: .module)
    static let dismiss = String(localized: "error.dismiss", defaultValue: "Dismiss", bundle: .module)
    static let errorServerNotConfigured = String(localized: "error.serverNotConfigured", defaultValue: "No server address is set. Add one in Settings.", bundle: .module)
    static let errorNoModel = String(localized: "error.noModel", defaultValue: "Choose a model first.", bundle: .module)
    static let errorUnreachable = String(localized: "error.unreachable", defaultValue: "Could not reach the server. Check that your VPN is connected.", bundle: .module)
    static let errorSpeechNotConfigured = String(localized: "error.speechNotConfigured", defaultValue: "No speech server address is set. Add one in Settings.", bundle: .module)
    static let errorDictationDenied = String(localized: "error.dictationDenied", defaultValue: "Allow microphone and speech recognition access in the Settings app to dictate.", bundle: .module)
    static let errorDictationUnavailable = String(localized: "error.dictationUnavailable", defaultValue: "Dictation is not available right now.", bundle: .module)
    static let errorSpeechFailed = String(localized: "error.speechFailed", defaultValue: "The reply could not be spoken.", bundle: .module)
    static let interruptedTitle = String(localized: "error.interruptedTitle", defaultValue: "Reply interrupted", bundle: .module)
    static let interruptedMessage = String(localized: "error.interruptedMessage", defaultValue: "Hearth was in the background for too long and iOS paused it. What arrived is kept.", bundle: .module)
    static let errorSaveFailed = String(localized: "error.saveFailed", defaultValue: "This chat could not be saved.", bundle: .module)

    static let searchChats = String(localized: "sidebar.search", defaultValue: "Search chats", bundle: .module)
    static let today = String(localized: "sidebar.today", defaultValue: "Today", bundle: .module)
    static let yesterday = String(localized: "sidebar.yesterday", defaultValue: "Yesterday", bundle: .module)
    static let previousWeek = String(localized: "sidebar.previousWeek", defaultValue: "Previous 7 days", bundle: .module)
    static let earlier = String(localized: "sidebar.earlier", defaultValue: "Earlier", bundle: .module)
    static let pinned = String(localized: "sidebar.pinned", defaultValue: "Pinned", bundle: .module)
    static let pin = String(localized: "sidebar.pin", defaultValue: "Pin", bundle: .module)
    static let unpin = String(localized: "sidebar.unpin", defaultValue: "Unpin", bundle: .module)
    static let rename = String(localized: "sidebar.rename", defaultValue: "Rename", bundle: .module)
    static let renameChat = String(localized: "sidebar.renameChat", defaultValue: "Rename chat", bundle: .module)
    static let chatTitle = String(localized: "sidebar.chatTitle", defaultValue: "Title", bundle: .module)
    static let save = String(localized: "sidebar.save", defaultValue: "Save", bundle: .module)
    static let delete = String(localized: "sidebar.delete", defaultValue: "Delete", bundle: .module)
    static let noChats = String(localized: "sidebar.empty", defaultValue: "No chats yet", bundle: .module)
    static let settings = String(localized: "sidebar.settings", defaultValue: "Settings", bundle: .module)
    static let notConnected = String(localized: "sidebar.notConnected", defaultValue: "Not connected", bundle: .module)
    static let noServer = String(localized: "sidebar.noServer", defaultValue: "No server set", bundle: .module)

    static let done = String(localized: "settings.done", defaultValue: "Done", bundle: .module)
    static let cancel = String(localized: "settings.cancel", defaultValue: "Cancel", bundle: .module)
    static let servers = String(localized: "settings.servers", defaultValue: "Servers", bundle: .module)
    static let ollamaAddress = String(localized: "settings.ollama", defaultValue: "Ollama address", bundle: .module)
    static let searchAddress = String(localized: "settings.search", defaultValue: "Search address (SearXNG)", bundle: .module)
    static let speechAddress = String(localized: "settings.speech", defaultValue: "Speech address (Kokoro)", bundle: .module)
    static let serversFooter = String(localized: "settings.serversFooter", defaultValue: "Search and speech are optional. An address without a scheme is taken to be HTTPS.", bundle: .module)
    static let voice = String(localized: "settings.voice", defaultValue: "Voice", bundle: .module)
    static let voiceName = String(localized: "settings.voiceName", defaultValue: "Voice name", bundle: .module)
    static let instructions = String(localized: "settings.instructions", defaultValue: "Custom instructions", bundle: .module)
    static let instructionsPlaceholder = String(localized: "settings.instructionsPlaceholder", defaultValue: "For example: answer briefly. I live in Brisbane.", bundle: .module)
    static let instructionsFooter = String(localized: "settings.instructionsFooter", defaultValue: "Instructions are given to the model at the start of every conversation. Suggestions cost one extra short request per reply.", bundle: .module)
    static let readRepliesAloud = String(localized: "settings.readReplies", defaultValue: "Read replies aloud", bundle: .module)
    static let privacy = String(localized: "settings.privacy", defaultValue: "Privacy", bundle: .module)
    static let requireUnlock = String(localized: "settings.requireUnlock", defaultValue: "Require Face ID or passcode", bundle: .module)
    static let requireUnlockFooter = String(localized: "settings.requireUnlockFooter", defaultValue: "Asked for each time Hearth is opened. Your conversations are hidden in the app switcher.", bundle: .module)
    static let lockEnableReason = String(localized: "lock.enableReason", defaultValue: "Confirm it is you to turn on the lock.", bundle: .module)
    static let unlockReason = String(localized: "lock.reason", defaultValue: "Unlock your conversations.", bundle: .module)
    static let unlock = String(localized: "lock.unlock", defaultValue: "Unlock", bundle: .module)
    static let readPages = String(localized: "settings.readPages", defaultValue: "Read the pages a search finds", bundle: .module)
    static let readPagesFooter = String(localized: "settings.readPagesFooter", defaultValue: "Gives the model the text of the top results, not just a snippet. Your phone fetches those pages itself, so the sites see your phone's address rather than your server's.", bundle: .module)
    static let memory = String(localized: "memory.title", defaultValue: "Memory", bundle: .module)
    static let memoryToggle = String(localized: "memory.toggle", defaultValue: "Remember things about me", bundle: .module)
    static let savedMemories = String(localized: "memory.saved", defaultValue: "Saved memories", bundle: .module)
    static let memoryFooter = String(localized: "memory.footer", defaultValue: "Lasting facts you tell a model, or ask it to remember, are kept on this device and given to every conversation. Models that cannot call tools can read memories but not add to them.", bundle: .module)
    static let memoryPlaceholder = String(localized: "memory.placeholder", defaultValue: "For example: I live in Brisbane", bundle: .module)
    static let addMemory = String(localized: "memory.add", defaultValue: "Add memory", bundle: .module)
    static let memoryListFooter = String(localized: "memory.listFooter", defaultValue: "Up to 50 short memories. Swipe one to delete it, or tell the model to forget it.", bundle: .module)
    static let noMemories = String(localized: "memory.none", defaultValue: "Nothing is remembered yet.", bundle: .module)
    static let clearMemories = String(localized: "memory.clear", defaultValue: "Forget everything", bundle: .module)
    static let clearMemoriesQuestion = String(localized: "memory.clearQuestion", defaultValue: "Forget every saved memory?", bundle: .module)
    static let theme = String(localized: "settings.theme", defaultValue: "Theme", bundle: .module)
    static let themeSystem = String(localized: "settings.themeSystem", defaultValue: "System", bundle: .module)
    static let themeLight = String(localized: "settings.themeLight", defaultValue: "Light", bundle: .module)
    static let themeDark = String(localized: "settings.themeDark", defaultValue: "Dark", bundle: .module)
    static let testConnection = String(localized: "settings.test", defaultValue: "Test connection", bundle: .module)
    static let checking = String(localized: "settings.checking", defaultValue: "Checking…", bundle: .module)
    static let invalidAddress = String(localized: "settings.invalidAddress", defaultValue: "That Ollama address is not valid.", bundle: .module)

    static let listening = String(localized: "voice.listening", defaultValue: "Listening", bundle: .module)
    static let voiceThinking = String(localized: "voice.thinking", defaultValue: "Thinking", bundle: .module)
    static let speaking = String(localized: "voice.speaking", defaultValue: "Speaking", bundle: .module)
    static let muted = String(localized: "voice.muted", defaultValue: "Muted", bundle: .module)
    static let unavailable = String(localized: "voice.unavailable", defaultValue: "Unavailable", bundle: .module)
    static let mute = String(localized: "voice.mute", defaultValue: "Mute", bundle: .module)
    static let unmute = String(localized: "voice.unmute", defaultValue: "Unmute", bundle: .module)
    static let endVoice = String(localized: "voice.end", defaultValue: "End voice conversation", bundle: .module)
    static let interrupt = String(localized: "voice.interrupt", defaultValue: "Interrupt and listen", bundle: .module)
    static let voiceHint = String(localized: "voice.hint", defaultValue: "Speak when you are ready.", bundle: .module)
    static let voiceMutedHint = String(localized: "voice.mutedHint", defaultValue: "Unmute to carry on.", bundle: .module)
    static let voicePermissionDenied = String(localized: "voice.permissionDenied", defaultValue: "Allow microphone and speech recognition access in the Settings app to talk.", bundle: .module)

    static func messageModel(_ name: String) -> String {
        String(localized: "composer.placeholderModel", defaultValue: "Message \(name)", bundle: .module)
    }

    static func attachedFile(_ name: String) -> String {
        String(localized: "message.attachedFile", defaultValue: "Attached file \(name)", bundle: .module)
    }

    static func memorySaved(_ text: String) -> String {
        String(localized: "memory.noticeSaved", defaultValue: "Remembered: \(text)", bundle: .module)
    }

    static func memoryUpdated(_ text: String) -> String {
        String(localized: "memory.noticeUpdated", defaultValue: "Memory updated: \(text)", bundle: .module)
    }

    static func memoryForgotten(_ text: String) -> String {
        String(localized: "memory.noticeForgotten", defaultValue: "Forgotten: \(text)", bundle: .module)
    }

    static func searching(for query: String) -> String {
        String(localized: "message.searching", defaultValue: "Searching the web for \(query)", bundle: .module)
    }

    static func thought(seconds: Int) -> String {
        String(localized: "message.thought", defaultValue: "Thought for \(seconds) seconds", bundle: .module)
    }

    static func connected(modelCount: Int) -> String {
        String(localized: "sidebar.connected", defaultValue: "Connected · \(modelCount) models", bundle: .module)
    }

    static func testSucceeded(modelCount: Int) -> String {
        String(localized: "settings.testOK", defaultValue: "Connected. \(modelCount) models found.", bundle: .module)
    }

    static func source(number: Int, host: String) -> String {
        String(localized: "message.source", defaultValue: "Source \(number): \(host)", bundle: .module)
    }
}
// swiftlint:enable line_length
