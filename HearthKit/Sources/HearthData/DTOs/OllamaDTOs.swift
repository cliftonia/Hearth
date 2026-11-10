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

/// What a model was asked to look up when it called the web search tool.
public struct OllamaToolArgumentsDTO: Codable, Sendable, Equatable {
    public let query: String?
    /// "news" when the model wants current events rather than the general web.
    public let category: String?
    /// The fact to remember, for the memory tools.
    public let text: String?
    /// Which saved memory to change or forget, for the memory tools.
    public let id: String?

    public init(query: String? = nil, category: String? = nil, text: String? = nil, id: String? = nil) {
        self.query = query
        self.category = category
        self.text = text
        self.id = id
    }
}

public struct OllamaToolFunctionDTO: Codable, Sendable, Equatable {
    public let name: String
    public let arguments: OllamaToolArgumentsDTO

    public init(name: String, arguments: OllamaToolArgumentsDTO) {
        self.name = name
        self.arguments = arguments
    }
}

public struct OllamaToolCallDTO: Codable, Sendable, Equatable {
    public let function: OllamaToolFunctionDTO

    public init(function: OllamaToolFunctionDTO) {
        self.function = function
    }
}

public struct OllamaToolPropertyDTO: Encodable, Sendable, Equatable {
    public let type: String
    public let description: String
    /// The only values the model may give, when the property is a choice.
    public let allowedValues: [String]?

    public init(type: String, description: String, allowedValues: [String]? = nil) {
        self.type = type
        self.description = description
        self.allowedValues = allowedValues
    }

    enum CodingKeys: String, CodingKey {
        case type
        case description
        case allowedValues = "enum"
    }
}

public struct OllamaToolParametersDTO: Encodable, Sendable, Equatable {
    public let type: String
    public let properties: [String: OllamaToolPropertyDTO]
    public let required: [String]
}

public struct OllamaToolSpecDTO: Encodable, Sendable, Equatable {
    public let name: String
    public let description: String
    public let parameters: OllamaToolParametersDTO
}

/// A tool offered to the model. The app offers one: a web search.
public struct OllamaToolDTO: Encodable, Sendable, Equatable {
    public static let webSearchName = "web_search"
    public static let newsCategory = "news"

    public let type: String
    public let function: OllamaToolSpecDTO

    public static let saveMemoryName = "save_memory"
    public static let updateMemoryName = "update_memory"
    public static let deleteMemoryName = "delete_memory"

    /// The three tools with which a model keeps what it remembers about the user.
    public static let memory: [OllamaToolDTO] = [
        tool(saveMemoryName, "Remember a lasting fact about the user for future conversations.", ["text": "The fact, as one short sentence"]),
        tool(
            updateMemoryName,
            "Replace a saved memory that has changed or was wrong.",
            ["id": "The id of the memory, such as m3", "text": "The corrected fact"]
        ),
        tool(deleteMemoryName, "Forget a saved memory.", ["id": "The id of the memory, such as m3"])
    ]

    private static func tool(_ name: String, _ description: String, _ properties: [String: String]) -> OllamaToolDTO {
        OllamaToolDTO(
            type: "function",
            function: OllamaToolSpecDTO(
                name: name,
                description: description,
                parameters: OllamaToolParametersDTO(
                    type: "object",
                    properties: properties.mapValues { OllamaToolPropertyDTO(type: "string", description: $0) },
                    required: properties.keys.sorted()
                )
            )
        )
    }

    public static let webSearch = OllamaToolDTO(
        type: "function",
        function: OllamaToolSpecDTO(
            name: webSearchName,
            description: "Search the web for current or factual information. The text of the top pages is returned.",
            parameters: OllamaToolParametersDTO(
                type: "object",
                properties: [
                    "query": OllamaToolPropertyDTO(type: "string", description: "What to search for"),
                    "category": OllamaToolPropertyDTO(
                        type: "string",
                        description: "Use news for current events, headlines and anything from the last few days.",
                        allowedValues: ["general", newsCategory]
                    )
                ],
                required: ["query"]
            )
        )
    )
}

public struct OllamaMessageDTO: Encodable, Sendable, Equatable {
    public let role: String
    public let content: String
    public let imagesBase64: [String]?
    /// On an assistant message: the tool calls the model made in that turn.
    public let toolCalls: [OllamaToolCallDTO]?
    /// On a tool message: the tool whose result this is.
    public let toolName: String?

    public init(role: String, content: String, imagesBase64: [String]? = nil, toolCalls: [OllamaToolCallDTO]? = nil, toolName: String? = nil) {
        self.role = role
        self.content = content
        self.imagesBase64 = imagesBase64
        self.toolCalls = toolCalls
        self.toolName = toolName
    }

    enum CodingKeys: String, CodingKey {
        case role
        case content
        case imagesBase64 = "images"
        case toolCalls = "tool_calls"
        case toolName = "tool_name"
    }
}

/// How hard a thinking model should think: on or off, or a named level for models that grade it.
public enum OllamaThinkDTO: Encodable, Sendable, Equatable {
    case enabled(Bool)
    case level(String)

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .enabled(let isEnabled):
            try container.encode(isEnabled)
        case .level(let level):
            try container.encode(level)
        }
    }
}

public struct OllamaChatRequestDTO: Encodable, Sendable, Equatable {
    public let model: String
    public let messages: [OllamaMessageDTO]
    public let stream: Bool
    /// Left out entirely for models that cannot think; Ollama rejects the field for those.
    public let think: OllamaThinkDTO?
    /// Left out unless the model may call tools in this request.
    public let tools: [OllamaToolDTO]?

    public init(model: String, messages: [OllamaMessageDTO], stream: Bool, think: OllamaThinkDTO?, tools: [OllamaToolDTO]? = nil) {
        self.model = model
        self.messages = messages
        self.stream = stream
        self.think = think
        self.tools = tools
    }
}

public struct OllamaChunkMessageDTO: Decodable, Sendable, Equatable {
    public let content: String?
    public let thinking: String?
    public let toolCalls: [OllamaToolCallDTO]?

    enum CodingKeys: String, CodingKey {
        case content
        case thinking
        case toolCalls = "tool_calls"
    }
}

public struct OllamaChatChunkDTO: Decodable, Sendable, Equatable {
    public let message: OllamaChunkMessageDTO?
    public let done: Bool?
    public let error: String?

    /// Decodes one line of the newline-delimited JSON that `/api/chat` streams.
    public init(line: String) throws {
        self = try JSONDecoder().decode(OllamaChatChunkDTO.self, from: Data(line.utf8))
    }
}
