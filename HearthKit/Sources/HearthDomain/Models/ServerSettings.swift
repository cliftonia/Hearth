import Foundation

/// Where the user's services live, and how replies should sound.
public struct ServerSettings: Hashable, Codable, Sendable {
    public static let defaultVoice = "bf_emma"

    public let ollamaAddress: String
    public let searchAddress: String
    public let speechAddress: String
    public let voice: String
    public let defaultModelID: ChatModel.ID?

    public init(
        ollamaAddress: String = "",
        searchAddress: String = "",
        speechAddress: String = "",
        voice: String = ServerSettings.defaultVoice,
        defaultModelID: ChatModel.ID? = nil
    ) {
        self.ollamaAddress = ollamaAddress
        self.searchAddress = searchAddress
        self.speechAddress = speechAddress
        self.voice = voice
        self.defaultModelID = defaultModelID
    }

    public var ollamaURL: URL? { Self.url(from: ollamaAddress) }
    public var searchURL: URL? { Self.url(from: searchAddress) }
    public var speechURL: URL? { Self.url(from: speechAddress) }

    /// The host of the chat server, for display.
    public var ollamaHost: String? { ollamaURL?.host() }

    public func updating(defaultModelID: ChatModel.ID) -> ServerSettings {
        ServerSettings(
            ollamaAddress: ollamaAddress,
            searchAddress: searchAddress,
            speechAddress: speechAddress,
            voice: voice,
            defaultModelID: defaultModelID
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
