import Foundation
@testable import HearthData
import Testing

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

    @Test(arguments: [(true, true), (false, true), (nil, false)] as [(Bool?, Bool)])
    func `think is sent only when it has a value`(think: Bool?, isPresent: Bool) throws {
        let request = OllamaChatRequestDTO(model: "m", messages: [], stream: true, think: think)

        let json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any])

        #expect((json["think"] != nil) == isPresent)
    }

    @Test func `images are sent under the key Ollama expects`() throws {
        let message = OllamaMessageDTO(role: "user", content: "Look", imagesBase64: ["QUJD"])

        let json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(message)) as? [String: Any])

        #expect(json["images"] as? [String] == ["QUJD"])
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
