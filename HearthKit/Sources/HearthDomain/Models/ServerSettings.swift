import Foundation

/// Whether the app follows the phone's light or dark appearance, or keeps to one.
public enum AppearanceKind: String, Codable, Sendable, CaseIterable {
    case system
    case light
    case dark
}

/// Where the user's services live, how replies should sound and how the app should look.
public struct ServerSettings: Hashable, Codable, Sendable {
    public static let defaultVoice = "bf_emma"

    public let ollamaAddress: String
    public let searchAddress: String
    public let speechAddress: String
    public let voice: String
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

    public init(
        ollamaAddress: String = "",
        searchAddress: String = "",
        speechAddress: String = "",
        voice: String = ServerSettings.defaultVoice,
        defaultModelID: ChatModel.ID? = nil,
        appearance: AppearanceKind = .system,
        customInstructions: String = "",
        isAutoReadEnabled: Bool = false,
        isLockEnabled: Bool = false,
        isFollowUpsEnabled: Bool = true
    ) {
        self.ollamaAddress = ollamaAddress
        self.searchAddress = searchAddress
        self.speechAddress = speechAddress
        self.voice = voice
        self.defaultModelID = defaultModelID
        self.appearance = appearance
        self.customInstructions = customInstructions
        self.isAutoReadEnabled = isAutoReadEnabled
        self.isLockEnabled = isLockEnabled
        self.isFollowUpsEnabled = isFollowUpsEnabled
    }

    /// Settings saved before a field existed are read with that field's default, so nothing saved is lost.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            ollamaAddress: try container.decodeIfPresent(String.self, forKey: .ollamaAddress) ?? "",
            searchAddress: try container.decodeIfPresent(String.self, forKey: .searchAddress) ?? "",
            speechAddress: try container.decodeIfPresent(String.self, forKey: .speechAddress) ?? "",
            voice: try container.decodeIfPresent(String.self, forKey: .voice) ?? Self.defaultVoice,
            defaultModelID: try container.decodeIfPresent(ChatModel.ID.self, forKey: .defaultModelID),
            appearance: try container.decodeIfPresent(AppearanceKind.self, forKey: .appearance) ?? .system,
            customInstructions: try container.decodeIfPresent(String.self, forKey: .customInstructions) ?? "",
            isAutoReadEnabled: try container.decodeIfPresent(Bool.self, forKey: .isAutoReadEnabled) ?? false,
            isLockEnabled: try container.decodeIfPresent(Bool.self, forKey: .isLockEnabled) ?? false,
            isFollowUpsEnabled: try container.decodeIfPresent(Bool.self, forKey: .isFollowUpsEnabled) ?? true
        )
    }

    public var ollamaURL: URL? { Self.url(from: ollamaAddress) }
    public var searchURL: URL? { Self.url(from: searchAddress) }
    public var speechURL: URL? { Self.url(from: speechAddress) }

    /// The host of the chat server, for display.
    public var ollamaHost: String? { ollamaURL?.host() }

    public func updating(defaultModelID: ChatModel.ID? = nil, appearance: AppearanceKind? = nil, isAutoReadEnabled: Bool? = nil) -> ServerSettings {
        ServerSettings(
            ollamaAddress: ollamaAddress,
            searchAddress: searchAddress,
            speechAddress: speechAddress,
            voice: voice,
            defaultModelID: defaultModelID ?? self.defaultModelID,
            appearance: appearance ?? self.appearance,
            customInstructions: customInstructions,
            isAutoReadEnabled: isAutoReadEnabled ?? self.isAutoReadEnabled,
            isLockEnabled: isLockEnabled,
            isFollowUpsEnabled: isFollowUpsEnabled
        )
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
