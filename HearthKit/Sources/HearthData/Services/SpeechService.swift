import Foundation

public struct SpeechRequestDTO: Encodable, Sendable {
    public let model: String
    public let input: String
    public let voice: String
    public let responseFormat: String

    enum CodingKeys: String, CodingKey {
        case model
        case input
        case voice
        case responseFormat = "response_format"
    }
}

public struct SpeechVoicesDTO: Decodable, Sendable {
    public let voices: [String]

    private struct Voice: Decodable {
        let id: String
    }

    enum CodingKeys: String, CodingKey {
        case voices
    }

    /// Kokoro has answered with bare names and with objects, depending on its version.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let names = try? container.decode([String].self, forKey: .voices) {
            self.voices = names
        } else {
            self.voices = try container.decode([Voice].self, forKey: .voices).map(\.id)
        }
    }
}

/// Turns text into speech through an OpenAI-compatible endpoint such as Kokoro-FastAPI.
public struct SpeechService: Sendable {
    private let session: URLSession

    public init(session: URLSession = .hearth) {
        self.session = session
    }

    /// MP3 audio of the text, spoken in the given voice.
    public func synthesize(baseURL: URL, text: String, voice: String) async throws -> Data {
        let body = SpeechRequestDTO(model: "kokoro", input: text, voice: voice, responseFormat: "mp3")
        var request = try URLRequest.jsonPost(url: baseURL.appending(path: "v1/audio/speech"), body: body)
        request.timeoutInterval = 60
        return try await session.validatedData(for: request)
    }

    public func fetchVoices(baseURL: URL) async throws -> [String] {
        var request = URLRequest(url: baseURL.appending(path: "v1/audio/voices"))
        request.timeoutInterval = 15
        return try await session.decoded(SpeechVoicesDTO.self, for: request).voices
    }
}
