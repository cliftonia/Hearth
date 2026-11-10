import Foundation
@testable import HearthDomain
import Testing

struct SentenceChunkerTests {
    @Test func `sentences are released only once they are complete`() {
        var chunker = SentenceChunker()

        #expect(chunker.append("The models are listed by the ps comm").isEmpty)
        #expect(chunker.append("and. It shows what is loaded") == ["The models are listed by the ps command."])
        #expect(chunker.finish() == ["It shows what is loaded"])
    }

    @Test func `a short opening waits to be joined with what follows`() {
        var chunker = SentenceChunker()

        #expect(chunker.append("Yes. ").isEmpty)
        #expect(chunker.append("That is exactly how it works. And") == ["Yes. That is exactly how it works."])
    }

    @Test func `a decimal point does not end a sentence`() {
        var chunker = SentenceChunker()

        let sentences = chunker.append("Version 0.40 is the one that is installed here") + chunker.finish()

        #expect(sentences == ["Version 0.40 is the one that is installed here"])
    }

    @Test func `nothing is spoken for text with no words in it`() {
        var chunker = SentenceChunker()

        #expect((chunker.append("---\n\n") + chunker.finish()).isEmpty)
    }

    @Test(arguments: [
        ("**Bold** and `code` here", "Bold and code here"),
        ("## A heading", "A heading"),
        ("- first item", "first item"),
        ("See [the docs](https://example.com/docs) for more [1]", "See the docs for more"),
        ("Run this:\n```bash\nollama ps\n```\nDone.", "Run this:\n \nDone.")
    ])
    func `markup is removed before text is spoken`(markdown: String, spoken: String) {
        #expect(SentenceChunker.speakable(markdown) == spoken)
    }
}

struct MarkdownTransformerTests {
    private func kinds(_ markdown: String) -> [MarkdownBlockKind] {
        MarkdownTransformer().blocks(from: markdown).map(\.kind)
    }

    @Test func `a reply is split into its blocks in order`() {
        let markdown = """
        # Title
        First line
        second line

        - one
        - two

        1. alpha
        2. beta

        > quoted
        ---
        """

        #expect(kinds(markdown) == [
            .heading(level: 1, text: "Title"),
            .paragraph("First line\nsecond line"),
            .list(isOrdered: false, items: ["one", "two"]),
            .list(isOrdered: true, items: ["alpha", "beta"]),
            .quote("quoted"),
            .rule
        ])
    }

    @Test func `code keeps its language, indentation and markup characters`() {
        let markdown = "```swift\nlet x = 1\n    # not a heading\n```"

        #expect(kinds(markdown) == [.code(language: "swift", text: "let x = 1\n    # not a heading")])
    }

    @Test func `code still being streamed is shown without its closing fence`() {
        #expect(kinds("Here:\n```\nollama p") == [.paragraph("Here:"), .code(language: nil, text: "ollama p")])
    }

    @Test func `block identifiers are stable positions`() {
        #expect(MarkdownTransformer().blocks(from: "one\n\ntwo").map(\.id) == [0, 1])
    }
}

struct PromptBuilderTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func `the system message comes first and history keeps its order`() {
        let history = [Message(role: .user, text: "Hello"), Message(role: .assistant, text: "Hi"), Message(role: .user, text: "Again")]

        let messages = PromptBuilder().messages(history: history, sources: [], style: .chat, now: now)

        #expect(messages.map(\.role) == [.system, .user, .assistant, .user])
        #expect(messages.dropFirst().map(\.text) == ["Hello", "Hi", "Again"])
    }

    @Test func `an empty reply left by a failed turn is not sent back`() {
        let history = [Message(role: .user, text: "Hello"), Message(role: .assistant, text: "")]

        let messages = PromptBuilder().messages(history: history, sources: [], style: .chat, now: now)

        #expect(messages.map(\.role) == [.system, .user])
    }

    @Test func `sources are numbered in the system message`() throws {
        let source = SearchSource(title: "Ollama docs", url: try #require(URL(string: "https://docs.example.com/ps")), snippet: "Lists models.")

        let system = try #require(PromptBuilder().messages(history: [], sources: [source], style: .chat, now: now).first)

        #expect(system.text.contains("[1] Ollama docs\nhttps://docs.example.com/ps\nLists models."))
    }

    @Test func `a voice reply is asked for without markup`() throws {
        let system = try #require(PromptBuilder().messages(history: [], sources: [], style: .voice, now: now).first)

        #expect(system.text.contains("spoken aloud"))
        #expect(!system.text.contains("Format replies in Markdown"))
    }

    @Test func `photos travel with the message they were attached to`() {
        let photo = Data([1, 2, 3])

        let messages = PromptBuilder().messages(history: [Message(role: .user, text: "", imagesJPEG: [photo])], sources: [], style: .chat, now: now)

        #expect(messages.last?.imagesJPEG == [photo])
    }

    @Test func `the search query is the latest user message on one line`() {
        let history = [Message(role: .user, text: "old"), Message(role: .assistant, text: "reply"), Message(role: .user, text: "new\nquestion")]

        #expect(PromptBuilder().searchQuery(history: history) == "new question")
        #expect(PromptBuilder().searchQuery(history: []) == nil)
    }
}

struct ServerSettingsTests {
    @Test(arguments: [
        ("https://server.example.ts.net", "https://server.example.ts.net"),
        ("server.example.ts.net:8888", "https://server.example.ts.net:8888"),
        ("  http://100.64.0.1:8880  ", "http://100.64.0.1:8880")
    ])
    func `an address is read with or without a scheme`(address: String, expected: String) {
        #expect(ServerSettings(ollamaAddress: address).ollamaURL?.absoluteString == expected)
    }

    @Test(arguments: ["", "   ", "https://"])
    func `an address with no host is no address`(address: String) {
        #expect(ServerSettings(ollamaAddress: address).ollamaURL == nil)
    }
}

struct ChatModelTests {
    @Test(arguments: [
        ("gemma4:latest", "gemma4"),
        ("kimi-k3:cloud", "kimi-k3"),
        ("qwen3.6:35b-a3b", "qwen3.6:35b-a3b"),
        ("huihui_ai/gemma-4-abliterated:latest", "gemma-4-abliterated")
    ])
    func `the display name drops the tags that say nothing`(name: String, displayName: String) {
        #expect(ChatModel(id: ChatModel.ID(name)).displayName == displayName)
    }
}
