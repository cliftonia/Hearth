import Foundation
@testable import HearthData
import Testing

/// How requests and replies are written to and read from the JSON the servers speak.
struct OllamaDTOTests {
    @Test func `a streamed line carries text and thinking`() throws {
        let chunk = try OllamaChatChunkDTO(line: #"{"model":"m","message":{"role":"assistant","content":"Hi","thinking":"Hm"},"done":false}"#)

        #expect(chunk.message?.content == "Hi")
        #expect(chunk.message?.thinking == "Hm")
        #expect(chunk.done == false)
        #expect(chunk.error == nil)
    }

    @Test func `an error line is decoded rather than thrown away`() throws {
        let chunk = try OllamaChatChunkDTO(line: #"{"error":"model requires more system memory"}"#)

        #expect(chunk.error == "model requires more system memory")
        #expect(chunk.message == nil)
    }

    @Test func `a line that is not JSON throws`() {
        #expect(throws: (any Error).self) {
            try OllamaChatChunkDTO(line: "<html>502 Bad Gateway</html>")
        }
    }

    /// The value as the JSON object it is sent as.
    private func json(_ value: some Encodable) throws -> [String: Any] {
        try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any])
    }

    @Test func `think is sent as a switch or a level, and left out when it has no value`() throws {
        let off = try json(OllamaChatRequestDTO(model: "m", messages: [], stream: true, think: .enabled(false)))
        let high = try json(OllamaChatRequestDTO(model: "m", messages: [], stream: true, think: .level("high")))
        let none = try json(OllamaChatRequestDTO(model: "m", messages: [], stream: true, think: nil))

        #expect(off["think"] as? Bool == false)
        #expect(high["think"] as? String == "high")
        #expect(none["think"] == nil)
    }

    @Test func `a context size is sent as num_ctx among the options, and left out when there is none`() throws {
        let options = OllamaOptionsDTO(contextLength: 8192)
        let sized = try json(OllamaChatRequestDTO(model: "m", messages: [], stream: true, think: nil, options: options))
        let plain = try json(OllamaChatRequestDTO(model: "m", messages: [], stream: true, think: nil))

        #expect((sized["options"] as? [String: Any])?["num_ctx"] as? Int == 8192)
        #expect(plain["options"] == nil)
    }

    @Test func `what a model can read at once, and any size its settings fix, are read from its description`() throws {
        let open = #"{"parameters": "top_p 0.95\ntemperature    1", "model_info": {"general.name": "x", "qwen35.context_length": 262144, "tokens": ["a"]}}"#
        let fixed = #"{"parameters": "stop \"<end>\"\nnum_ctx                        131072", "model_info": {"gemma3.context_length": 131072}}"#

        #expect(try shown(open) == OllamaModelShowDTO(contextLength: 262_144, fixedContextLength: nil))
        #expect(try shown(fixed) == OllamaModelShowDTO(contextLength: 131_072, fixedContextLength: 131_072))
        #expect(try shown("{}") == OllamaModelShowDTO(contextLength: nil, fixedContextLength: nil))
    }

    private func shown(_ json: String) throws -> OllamaModelShowDTO {
        try JSONDecoder().decode(OllamaModelShowDTO.self, from: Data(json.utf8))
    }

    @Test func `the web search tool is offered with its query parameter, and left out otherwise`() throws {
        let offered = try json(OllamaChatRequestDTO(model: "m", messages: [], stream: true, think: nil, tools: [.webSearch]))
        let plain = try json(OllamaChatRequestDTO(model: "m", messages: [], stream: true, think: nil))

        let function = try #require((offered["tools"] as? [[String: Any]])?.first?["function"] as? [String: Any])
        let parameters = try #require(function["parameters"] as? [String: Any])
        #expect(function["name"] as? String == "web_search")
        #expect(parameters["required"] as? [String] == ["query"])
        let category = try #require((parameters["properties"] as? [String: Any])?["category"] as? [String: Any])
        #expect(category["enum"] as? [String] == ["general", "news"])
        #expect(plain["tools"] == nil)
    }

    @Test func `a streamed tool call carries the query the model asked for`() throws {
        let call = #"{"id":"call_1","function":{"index":0,"name":"web_search","arguments":{"query":"latest Swift","category":"news"}}}"#
        let line = #"{"message":{"role":"assistant","content":"","tool_calls":[\#(call)]},"done":false}"#

        let decoded = try #require(try OllamaChatChunkDTO(line: line).message?.toolCalls?.first)

        #expect(decoded.function.name == "web_search")
        #expect(decoded.function.arguments.query == "latest Swift")
        #expect(decoded.function.arguments.category == "news")
    }

    @Test func `a tool call and its result are sent back under the keys Ollama expects`() throws {
        let call = OllamaToolCallDTO(function: OllamaToolFunctionDTO(name: "web_search", arguments: OllamaToolArgumentsDTO(query: "q")))
        let asked = try json(OllamaMessageDTO(role: "assistant", content: "", toolCalls: [call]))
        let result = try json(OllamaMessageDTO(role: "tool", content: "[1] …", toolName: "web_search"))

        #expect((asked["tool_calls"] as? [[String: Any]])?.count == 1)
        #expect(result["tool_name"] as? String == "web_search")
        #expect(result["tool_calls"] == nil)
    }

    @Test func `the memory tools are three, each naming what it needs`() throws {
        let request = try json(OllamaChatRequestDTO(model: "m", messages: [], stream: true, think: nil, tools: OllamaToolDTO.memory))

        let functions = try #require(request["tools"] as? [[String: Any]]).compactMap { $0["function"] as? [String: Any] }
        let required = functions.compactMap { ($0["parameters"] as? [String: Any])?["required"] as? [String] }
        #expect(functions.compactMap { $0["name"] as? String } == ["save_memory", "update_memory", "delete_memory"])
        #expect(required == [["text"], ["id", "text"], ["id"]])
    }

    @Test func `a memory tool call carries its text and id`() throws {
        let line = #"{"message":{"content":"","tool_calls":[{"function":{"name":"update_memory","arguments":{"id":"m3","text":"Lives in Sydney."}}}]}}"#

        let call = try #require(try OllamaChatChunkDTO(line: line).message?.toolCalls?.first)

        #expect(call.function.name == "update_memory")
        #expect(call.function.arguments.id == "m3")
        #expect(call.function.arguments.text == "Lives in Sydney.")
        #expect(call.function.arguments.query == nil)
    }

    @Test func `images are sent under the key Ollama expects`() throws {
        let message = OllamaMessageDTO(role: "user", content: "Look", imagesBase64: ["QUJD"])

        #expect(try json(message)["images"] as? [String] == ["QUJD"])
    }

    @Test func `a model listing reads capabilities and its remote host`() throws {
        let json = #"""
        {"models":[
          {"name":"kimi:cloud","remote_host":"https://ollama.com","details":{"parameter_size":"2.8T"},"capabilities":["completion","thinking"]},
          {"name":"embed:latest","details":{},"capabilities":["embedding"]}
        ]}
        """#

        let models = try JSONDecoder().decode(OllamaTagsDTO.self, from: Data(json.utf8)).models

        #expect(models.map(\.name) == ["kimi:cloud", "embed:latest"])
        #expect(models[0].remoteHost == "https://ollama.com")
        #expect(models[0].details?.parameterSize == "2.8T")
        #expect(models[1].remoteHost == nil)
    }

    @Test(arguments: [
        #"{"voices":["af_heart","bf_emma"]}"#,
        #"{"voices":[{"id":"af_heart","name":"af_heart"},{"id":"bf_emma"}]}"#
    ])
    func `voices decode from either shape the speech server answers with`(json: String) throws {
        let voices = try JSONDecoder().decode(SpeechVoicesDTO.self, from: Data(json.utf8)).voices

        #expect(voices == ["af_heart", "bf_emma"])
    }
}
