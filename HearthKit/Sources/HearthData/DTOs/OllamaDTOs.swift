import Foundation

public struct OllamaTagsDTO: Decodable, Sendable {
    public let models: [OllamaModelDTO]
}

public struct OllamaModelDetailsDTO: Decodable, Sendable {
    public let parameterSize: String?

    enum CodingKeys: String, CodingKey {
        case parameterSize = "parameter_size"
    }
}

public struct OllamaModelDTO: Decodable, Sendable {
    public let name: String
    public let remoteHost: String?
    public let details: OllamaModelDetailsDTO?
    public let capabilities: [String]?

    enum CodingKeys: String, CodingKey {
        case name
        case remoteHost = "remote_host"
        case details
        case capabilities
    }
}

public struct OllamaMessageDTO: Encodable, Sendable, Equatable {
    public let role: String
    public let content: String
    public let imagesBase64: [String]?

    public init(role: String, content: String, imagesBase64: [String]? = nil) {
        self.role = role
        self.content = content
        self.imagesBase64 = imagesBase64
    }

    enum CodingKeys: String, CodingKey {
        case role
        case content
        case imagesBase64 = "images"
    }
}

public struct OllamaChatRequestDTO: Encodable, Sendable, Equatable {
    public let model: String
    public let messages: [OllamaMessageDTO]
    public let stream: Bool
    /// Left out entirely for models that cannot think; Ollama rejects the field for those.
    public let think: Bool?

    public init(model: String, messages: [OllamaMessageDTO], stream: Bool, think: Bool?) {
        self.model = model
        self.messages = messages
        self.stream = stream
        self.think = think
    }
}

public struct OllamaChatChunkDTO: Decodable, Sendable, Equatable {
    public struct Message: Decodable, Sendable, Equatable {
        public let content: String?
        public let thinking: String?
    }

    public let message: Message?
    public let done: Bool?
    public let error: String?

    /// Decodes one line of the newline-delimited JSON that `/api/chat` streams.
    public init(line: String) throws {
        self = try JSONDecoder().decode(OllamaChatChunkDTO.self, from: Data(line.utf8))
    }
}
