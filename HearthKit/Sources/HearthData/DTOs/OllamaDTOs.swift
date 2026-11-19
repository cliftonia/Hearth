import Foundation

// MARK: - Model list

/// The answer to `/api/tags`: every model the server has.
public struct OllamaTagsDTO: Decodable, Sendable {
    public let models: [OllamaModelDTO]
}

/// The finer details of a model; only its size is read.
public struct OllamaModelDetailsDTO: Decodable, Sendable {
    public let parameterSize: String?

    enum CodingKeys: String, CodingKey {
        case parameterSize = "parameter_size"
    }
}

/// One model as the server lists it.
public struct OllamaModelDTO: Decodable, Sendable {
    public let name: String
    /// Present when the model runs on a remote host rather than on the server itself.
    public let remoteHost: String?
    public let details: OllamaModelDetailsDTO?
    /// What the model can do, such as `completion`, `vision` or `tools`; `nil` when the server does not say.
    public let capabilities: [String]?

    enum CodingKeys: String, CodingKey {
        case name
        case remoteHost = "remote_host"
        case details
        case capabilities
    }
}

/// The answer to `/api/show`: what one model was built with. Only what bears on how much it can read at once is kept.
public struct OllamaModelShowDTO: Decodable, Sendable, Equatable {
    /// The most tokens the model itself can take in, as its file records it; `nil` when the server does not say.
    public let contextLength: Int?
    /// The context size the model's own settings fix on the server, when whoever made it chose one.
    public let fixedContextLength: Int?

    public init(contextLength: Int?, fixedContextLength: Int?) {
        self.contextLength = contextLength
        self.fixedContextLength = fixedContextLength
    }

    private struct Key: CodingKey {
        let stringValue: String
        let intValue: Int? = nil

        init(_ name: String) {
            stringValue = name
        }

        init?(stringValue: String) {
            self.stringValue = stringValue
        }

        init?(intValue: Int) {
            nil
        }
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        // The model's details are keyed by its family, as in `gemma3.context_length`, among values of every kind.
        let details = try? container.nestedContainer(keyedBy: Key.self, forKey: Key("model_info"))
        contextLength = details?.allKeys
            .first { $0.stringValue.hasSuffix(".context_length") }
            .flatMap { try? details?.decode(Int.self, forKey: $0) }
        // The settings come as lines of text, a name and a value on each: `num_ctx    8192`.
        let settings = (try? container.decodeIfPresent(String.self, forKey: Key("parameters"))) ?? ""
        fixedContextLength = settings.split(whereSeparator: \.isNewline)
            .map { $0.split(whereSeparator: \.isWhitespace) }
            .first { $0.first == "num_ctx" }
            .flatMap { $0.last.flatMap { Int($0) } }
    }
}

/// The body of a request to `/api/show`.
struct OllamaShowRequestDTO: Encodable, Sendable {
    let model: String
}

// MARK: - Tools

/// What a model passed when it called a tool. Each tool fills in only the fields it uses.
public struct OllamaToolArgumentsDTO: Codable, Sendable, Equatable {
    /// What to search the web for, for the web search tool.
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

/// The tool a model called, by name, with what it passed.
public struct OllamaToolFunctionDTO: Codable, Sendable, Equatable {
    public let name: String
    public let arguments: OllamaToolArgumentsDTO

    public init(name: String, arguments: OllamaToolArgumentsDTO) {
        self.name = name
        self.arguments = arguments
    }
}

/// One tool call made by a model, in the wrapping Ollama gives it.
public struct OllamaToolCallDTO: Codable, Sendable, Equatable {
    public let function: OllamaToolFunctionDTO

    public init(function: OllamaToolFunctionDTO) {
        self.function = function
    }
}

/// One argument a tool accepts, described for the model.
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

/// The arguments a tool accepts, as a JSON Schema object.
public struct OllamaToolParametersDTO: Encodable, Sendable, Equatable {
    public let type: String
    public let properties: [String: OllamaToolPropertyDTO]
    public let required: [String]
}

/// What a tool is called, what it does and what it takes, as the model is told.
public struct OllamaToolSpecDTO: Encodable, Sendable, Equatable {
    public let name: String
    public let description: String
    public let parameters: OllamaToolParametersDTO
}

/// A tool offered to the model: the web search, or one of the three that keep its memory.
public struct OllamaToolDTO: Encodable, Sendable, Equatable {
    public static let webSearchName = "web_search"
    /// The category a model gives, and the search server takes, for a search of the news.
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

    /// A tool whose arguments are all required strings, each given with its description.
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

    /// The tool with which a model searches the web, for news if it says so.
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

// MARK: - Chat request

/// One message of the conversation as it is sent to the model.
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

/// How the server should run the model for one request. Only the context size is ever set.
public struct OllamaOptionsDTO: Encodable, Sendable, Equatable {
    /// How many tokens of conversation the model is given room for.
    public let contextLength: Int

    public init(contextLength: Int) {
        self.contextLength = contextLength
    }

    enum CodingKeys: String, CodingKey {
        case contextLength = "num_ctx"
    }
}

/// The body of a request to `/api/chat`.
public struct OllamaChatRequestDTO: Encodable, Sendable, Equatable {
    public let model: String
    public let messages: [OllamaMessageDTO]
    public let stream: Bool
    /// Left out entirely for models that cannot think; Ollama rejects the field for those.
    public let think: OllamaThinkDTO?
    /// Left out unless the model may call tools in this request.
    public let tools: [OllamaToolDTO]?
    /// Left out to run the model as the server would by itself.
    public let options: OllamaOptionsDTO?

    public init(
        model: String,
        messages: [OllamaMessageDTO],
        stream: Bool,
        think: OllamaThinkDTO?,
        tools: [OllamaToolDTO]? = nil,
        options: OllamaOptionsDTO? = nil
    ) {
        self.model = model
        self.messages = messages
        self.stream = stream
        self.think = think
        self.tools = tools
        self.options = options
    }
}

// MARK: - Chat reply

/// What one piece of a reply carries: text, thinking, tool calls, or any mix of them.
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

/// One piece of a reply from `/api/chat`: a streamed line, or the whole of a reply that was not streamed.
public struct OllamaChatChunkDTO: Decodable, Sendable, Equatable {
    public let message: OllamaChunkMessageDTO?
    public let done: Bool?
    /// Set when the server reports a failure in place of a reply.
    public let error: String?

    /// Decodes one line of the newline-delimited JSON that `/api/chat` streams.
    public init(line: String) throws {
        self = try JSONDecoder().decode(OllamaChatChunkDTO.self, from: Data(line.utf8))
    }
}

/// The models the server has in memory right now.
struct OllamaLoadedModelsDTO: Decodable, Sendable {
    struct Model: Decodable, Sendable {
        let name: String
    }

    let models: [Model]
}

/// A request that loads nothing and keeps nothing: it tells the server to unload the named model at once.
struct OllamaUnloadRequestDTO: Encodable, Sendable {
    let model: String
    let keepAlive = 0

    enum CodingKeys: String, CodingKey {
        case model
        case keepAlive = "keep_alive"
    }
}
