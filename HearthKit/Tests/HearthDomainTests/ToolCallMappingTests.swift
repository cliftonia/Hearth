import Foundation
import HearthData
@testable import HearthDomain
import Testing

/// How a tool call from the model is read into what the app is asked to do.
struct ToolCallMappingTests {
    /// A call of the named tool with the given arguments.
    private static func call(_ name: String, query: String? = nil, category: String? = nil, text: String? = nil, id: String? = nil) -> OllamaToolCallDTO {
        OllamaToolCallDTO(function: OllamaToolFunctionDTO(
            name: name,
            arguments: OllamaToolArgumentsDTO(query: query, category: category, text: text, id: id)
        ))
    }

    @Test func `a web search is read with its query, as news only when the model says so`() {
        #expect(ChatDelta(from: Self.call(OllamaToolDTO.webSearchName, query: "tides")) == .searchRequested(SearchRequest(query: "tides")))
        #expect(
            ChatDelta(from: Self.call(OllamaToolDTO.webSearchName, query: "tides", category: OllamaToolDTO.newsCategory))
                == .searchRequested(SearchRequest(query: "tides", kind: .news))
        )
    }

    @Test func `the memory tools are read as saving, changing and forgetting`() {
        #expect(ChatDelta(from: Self.call(OllamaToolDTO.saveMemoryName, text: "Likes tea")) == .memoryRequested(.save("Likes tea")))
        #expect(
            ChatDelta(from: Self.call(OllamaToolDTO.updateMemoryName, text: "Likes coffee", id: "m3"))
                == .memoryRequested(.update(Memory.ID("m3"), "Likes coffee"))
        )
        #expect(ChatDelta(from: Self.call(OllamaToolDTO.deleteMemoryName, id: "m3")) == .memoryRequested(.delete(Memory.ID("m3"))))
    }

    @Test(arguments: [
        call(OllamaToolDTO.webSearchName),
        call(OllamaToolDTO.webSearchName, query: ""),
        call(OllamaToolDTO.saveMemoryName),
        call(OllamaToolDTO.saveMemoryName, text: ""),
        call(OllamaToolDTO.updateMemoryName, text: "Likes coffee"),
        call(OllamaToolDTO.updateMemoryName, text: "Likes coffee", id: ""),
        call(OllamaToolDTO.updateMemoryName, text: "", id: "m3"),
        call(OllamaToolDTO.deleteMemoryName, id: ""),
        call(OllamaToolDTO.deleteMemoryName, text: "Likes tea"),
        call("make_coffee", query: "tides", text: "Likes tea", id: "m3")
    ])
    func `a call that lacks what it needs, or that the app does not know, is ignored`(call: OllamaToolCallDTO) {
        #expect(ChatDelta(from: call) == nil)
    }
}
