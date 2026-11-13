import Foundation

/// Whether the app follows the phone's light or dark appearance, or keeps to one.
public enum AppearanceKind: String, Codable, Sendable, CaseIterable {
    case system
    case light
    case dark
}

/// How hard a model that reasons should think before it replies.
public enum ThinkingLevelKind: String, Codable, Sendable, CaseIterable {
    case off
    case low
    case medium
    case high
}

/// Where the user's services live, how replies should sound and how the app should look.
public struct ServerSettings: Hashable, Codable, Sendable {
    /// The voice replies are spoken in until the user chooses another.
    public static let defaultVoice = "bf_emma"

    public let ollamaAddress: String
    public let searchAddress: String
    public let speechAddress: String
    /// Where pictures are made: a ComfyUI server. Blank means the app offers no pictures.
    public let imageAddress: String
    /// The model new pictures are made with. With none chosen, the first the server offers is used.
    public let imageModel: ImageModelKind?
    /// The voice replies are spoken in, by its name on the speech server.
    public let voice: String
    /// The model a new conversation starts with, if one has been chosen.
    public let defaultModelID: ChatModel.ID?
    public let appearance: AppearanceKind
    /// Standing instructions from the user, given to the model at the start of every conversation.
    public let customInstructions: String
    /// Whether each reply in a chat is spoken as soon as it is finished.
    public let isAutoReadEnabled: Bool
    /// Whether the app asks for Face ID, Touch ID or the passcode when it is opened.
    public let isLockEnabled: Bool
    /// Whether questions the user might ask next are suggested under each reply.
    public let isFollowUpsEnabled: Bool
    public let thinkingLevel: ThinkingLevelKind
    /// Whether the pages a search finds are fetched and read, not just their snippets. The phone fetches them itself.
    public let isPageReadingEnabled: Bool
    /// Whether lasting facts about the user are remembered and carried into every conversation.
    public let isMemoryEnabled: Bool

    public init(
        ollamaAddress: String = "",
        searchAddress: String = "",
        speechAddress: String = "",
        imageAddress: String = "",
        imageModel: ImageModelKind? = nil,
        voice: String = ServerSettings.defaultVoice,
        defaultModelID: ChatModel.ID? = nil,
        appearance: AppearanceKind = .system,
        customInstructions: String = "",
        isAutoReadEnabled: Bool = false,
        isLockEnabled: Bool = false,
        isFollowUpsEnabled: Bool = true,
        thinkingLevel: ThinkingLevelKind = .medium,
        isPageReadingEnabled: Bool = true,
        isMemoryEnabled: Bool = true
    ) {
        self.ollamaAddress = ollamaAddress
        self.searchAddress = searchAddress
        self.speechAddress = speechAddress
        self.imageAddress = imageAddress
        self.imageModel = imageModel
        self.voice = voice
        self.defaultModelID = defaultModelID
        self.appearance = appearance
        self.customInstructions = customInstructions
        self.isAutoReadEnabled = isAutoReadEnabled
        self.isLockEnabled = isLockEnabled
        self.isFollowUpsEnabled = isFollowUpsEnabled
        self.thinkingLevel = thinkingLevel
        self.isPageReadingEnabled = isPageReadingEnabled
        self.isMemoryEnabled = isMemoryEnabled
    }

    /// Settings saved before a field existed are read with that field's default, so nothing saved is lost.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            ollamaAddress: try container.decodeIfPresent(String.self, forKey: .ollamaAddress) ?? "",
            searchAddress: try container.decodeIfPresent(String.self, forKey: .searchAddress) ?? "",
            speechAddress: try container.decodeIfPresent(String.self, forKey: .speechAddress) ?? "",
            imageAddress: try container.decodeIfPresent(String.self, forKey: .imageAddress) ?? "",
            // A model the app no longer knows is read as no choice, not as a failure to read the settings.
            imageModel: (try? container.decodeIfPresent(ImageModelKind.self, forKey: .imageModel)) ?? nil,
            voice: try container.decodeIfPresent(String.self, forKey: .voice) ?? Self.defaultVoice,
            defaultModelID: try container.decodeIfPresent(ChatModel.ID.self, forKey: .defaultModelID),
            appearance: try container.decodeIfPresent(AppearanceKind.self, forKey: .appearance) ?? .system,
            customInstructions: try container.decodeIfPresent(String.self, forKey: .customInstructions) ?? "",
            isAutoReadEnabled: try container.decodeIfPresent(Bool.self, forKey: .isAutoReadEnabled) ?? false,
            isLockEnabled: try container.decodeIfPresent(Bool.self, forKey: .isLockEnabled) ?? false,
            isFollowUpsEnabled: try container.decodeIfPresent(Bool.self, forKey: .isFollowUpsEnabled) ?? true,
            thinkingLevel: try container.decodeIfPresent(ThinkingLevelKind.self, forKey: .thinkingLevel) ?? .medium,
            isPageReadingEnabled: try container.decodeIfPresent(Bool.self, forKey: .isPageReadingEnabled) ?? true,
            isMemoryEnabled: try container.decodeIfPresent(Bool.self, forKey: .isMemoryEnabled) ?? true
        )
    }

    /// The chat server's address in usable form; `nil` when it is blank or not an address. Likewise the two below.
    public var ollamaURL: URL? { Self.url(from: ollamaAddress) }
    public var searchURL: URL? { Self.url(from: searchAddress) }
    public var speechURL: URL? { Self.url(from: speechAddress) }
    public var imageURL: URL? { Self.url(from: imageAddress) }

    /// The host of the chat server, for display.
    public var ollamaHost: String? { ollamaURL?.host() }

    /// A copy with the given parts replaced; anything left `nil` is kept.
    public func updating(
        defaultModelID: ChatModel.ID? = nil,
        appearance: AppearanceKind? = nil,
        isAutoReadEnabled: Bool? = nil,
        thinkingLevel: ThinkingLevelKind? = nil,
        imageAddress: String? = nil
    ) -> ServerSettings {
        ServerSettings(
            ollamaAddress: ollamaAddress,
            searchAddress: searchAddress,
            speechAddress: speechAddress,
            imageAddress: imageAddress ?? self.imageAddress,
            imageModel: imageModel,
            voice: voice,
            defaultModelID: defaultModelID ?? self.defaultModelID,
            appearance: appearance ?? self.appearance,
            customInstructions: customInstructions,
            isAutoReadEnabled: isAutoReadEnabled ?? self.isAutoReadEnabled,
            isLockEnabled: isLockEnabled,
            isFollowUpsEnabled: isFollowUpsEnabled,
            thinkingLevel: thinkingLevel ?? self.thinkingLevel,
            isPageReadingEnabled: isPageReadingEnabled,
            isMemoryEnabled: isMemoryEnabled
        )
    }

    /// A copy that makes new pictures with the given model, or leaves the choice to the app when given none.
    public func choosing(imageModel: ImageModelKind?) -> ServerSettings {
        ServerSettings(
            ollamaAddress: ollamaAddress,
            searchAddress: searchAddress,
            speechAddress: speechAddress,
            imageAddress: imageAddress,
            imageModel: imageModel,
            voice: voice,
            defaultModelID: defaultModelID,
            appearance: appearance,
            customInstructions: customInstructions,
            isAutoReadEnabled: isAutoReadEnabled,
            isLockEnabled: isLockEnabled,
            isFollowUpsEnabled: isFollowUpsEnabled,
            thinkingLevel: thinkingLevel,
            isPageReadingEnabled: isPageReadingEnabled,
            isMemoryEnabled: isMemoryEnabled
        )
    }

    /// Whether a conversation may read and write memory: memory must be on, and the conversation not private.
    public func allowsMemory(in conversation: Conversation) -> Bool {
        isMemoryEnabled && !conversation.isPrivate
    }

    /// Accepts an address typed with or without a scheme; a bare host is taken to be HTTPS.
    static func url(from address: String) -> URL? {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }
        let withScheme = trimmed.contains("://") ? trimmed : "https://" + trimmed
        guard let url = URL(string: withScheme), url.host() != nil else {
            return nil
        }
        return url
    }
}
