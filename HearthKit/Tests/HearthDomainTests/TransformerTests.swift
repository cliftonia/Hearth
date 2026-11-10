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

    @Test func `a table is read into its header and rows`() {
        let markdown = "| Model | Size |\n|:--|--:|\n| gemma4 | 9 GB |\n| qwen | 23 GB |\nAfter"

        #expect(kinds(markdown) == [
            .table(header: ["Model", "Size"], rows: [["gemma4", "9 GB"], ["qwen", "23 GB"]]),
            .paragraph("After")
        ])
    }

    @Test func `a line of pipes without a row of dashes is ordinary text`() {
        #expect(kinds("| not | a table |") == [.paragraph("| not | a table |")])
    }

    @Test(arguments: ["$$ E = mc^2 $$", "\\[ E = mc^2 \\]", "$$\nE = mc^2\n$$"])
    func `display maths is its own block whichever way it is fenced`(markdown: String) {
        #expect(kinds(markdown) == [.math("E = mc^2")])
    }

    @Test func `block identifiers are stable positions`() {
        #expect(MarkdownTransformer().blocks(from: "one\n\ntwo").map(\.id) == [0, 1])
    }
}

struct PromptBuilderTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func `the system message comes first and history keeps its order`() {
        let history = [Message(role: .user, text: "Hello"), Message(role: .assistant, text: "Hi"), Message(role: .user, text: "Again")]

        let messages = PromptBuilder(instructions: "").messages(history: history, sources: [], style: .chat, now: now)

        #expect(messages.map(\.role) == [.system, .user, .assistant, .user])
        #expect(messages.dropFirst().map(\.text) == ["Hello", "Hi", "Again"])
    }

    @Test func `an empty reply left by a failed turn is not sent back`() {
        let history = [Message(role: .user, text: "Hello"), Message(role: .assistant, text: "")]

        let messages = PromptBuilder(instructions: "").messages(history: history, sources: [], style: .chat, now: now)

        #expect(messages.map(\.role) == [.system, .user])
    }

    @Test func `sources are numbered in the system message`() throws {
        let source = SearchSource(title: "Ollama docs", url: try #require(URL(string: "https://docs.example.com/ps")), snippet: "Lists models.")

        let system = try #require(PromptBuilder(instructions: "").messages(history: [], sources: [source], style: .chat, now: now).first)

        #expect(system.text.contains("[1] Ollama docs\nhttps://docs.example.com/ps\nLists models."))
    }

    @Test func `a voice reply is asked for without markup`() throws {
        let system = try #require(PromptBuilder(instructions: "").messages(history: [], sources: [], style: .voice, now: now).first)

        #expect(system.text.contains("spoken aloud"))
        #expect(!system.text.contains("Format replies in Markdown"))
    }

    @Test func `photos travel with the message they were attached to`() {
        let photo = Data([1, 2, 3])

        let history = [Message(role: .user, text: "", imagesJPEG: [photo])]

        let messages = PromptBuilder(instructions: "").messages(history: history, sources: [], style: .chat, now: now)

        #expect(messages.last?.imagesJPEG == [photo])
    }

    private func systemMessage(instructions: String) -> PromptMessage? {
        PromptBuilder(instructions: instructions).messages(history: [], sources: [], style: .chat, now: now).first
    }

    @Test func `standing instructions are given to the model and blank ones are not`() throws {
        let with = try #require(systemMessage(instructions: "  Answer briefly.\n"))
        let without = try #require(systemMessage(instructions: "  \n"))

        #expect(with.text.contains("standing instructions. Follow them:\nAnswer briefly."))
        #expect(!without.text.contains("standing instructions"))
    }

    @Test func `an attached file is read before what was typed, and a long one is cut short`() {
        let long = String(repeating: "x", count: PromptBuilder.maximumDocumentLength + 50)
        let message = Message(role: .user, text: "Summarise this.", documents: [AttachedDocument(name: "notes.md", text: long)])

        let sent = PromptBuilder(instructions: "").messages(history: [message], sources: [], style: .chat, now: now).last?.text ?? ""

        #expect(sent.hasPrefix("Attached file \"notes.md\":\nxxx"))
        #expect(sent.hasSuffix("x\n\nSummarise this."))
        #expect(sent.filter { $0 == "x" }.count == PromptBuilder.maximumDocumentLength)
    }

    @Test func `a message holding only a file is still sent`() {
        let message = Message(role: .user, text: "", documents: [AttachedDocument(name: "a.txt", text: "hello")])

        let messages = PromptBuilder(instructions: "").messages(history: [message], sources: [], style: .chat, now: now)

        #expect(messages.count == 2)
    }

    @Test func `the search query is the latest user message on one line`() {
        let history = [Message(role: .user, text: "old"), Message(role: .assistant, text: "reply"), Message(role: .user, text: "new\nquestion")]

        #expect(PromptBuilder(instructions: "").searchQuery(history: history) == "new question")
        #expect(PromptBuilder(instructions: "").searchQuery(history: []) == nil)
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

    @Test func `settings saved before the theme existed keep their addresses and follow the system`() throws {
        let json = #"{"ollamaAddress":"https://a.example","searchAddress":"","speechAddress":"http://b.example.ts.net:8880","voice":"af_heart"}"#

        let settings = try JSONDecoder().decode(ServerSettings.self, from: Data(json.utf8))

        #expect(settings.ollamaAddress == "https://a.example")
        #expect(settings.speechAddress == "http://b.example.ts.net:8880")
        #expect(settings.voice == "af_heart")
        #expect(settings.appearance == .system)
        #expect(settings.customInstructions.isEmpty)
        #expect(!settings.isAutoReadEnabled)
        #expect(!settings.isLockEnabled)
        #expect(settings.isFollowUpsEnabled)
    }

    @Test func `switching reading aloud leaves the other settings as they were`() {
        let settings = ServerSettings(ollamaAddress: "https://a.example", isLockEnabled: true, isFollowUpsEnabled: false)

        let reading = settings.updating(isAutoReadEnabled: true)

        #expect(reading.isAutoReadEnabled)
        #expect(reading.isLockEnabled)
        #expect(!reading.isFollowUpsEnabled)
        #expect(reading.ollamaAddress == "https://a.example")
    }

    @Test func `the lock and reading aloud survive a round trip and a change of theme`() throws {
        let settings = ServerSettings(customInstructions: "Be brief.", isAutoReadEnabled: true, isLockEnabled: true)

        let decoded = try JSONDecoder().decode(ServerSettings.self, from: JSONEncoder().encode(settings)).updating(appearance: .dark)

        #expect(decoded.isLockEnabled)
        #expect(decoded.isAutoReadEnabled)
        #expect(decoded.customInstructions == "Be brief.")
    }

    @Test(arguments: AppearanceKind.allCases)
    func `the theme survives a round trip and a change of model`(appearance: AppearanceKind) throws {
        let settings = ServerSettings(ollamaAddress: "https://a.example", appearance: appearance)

        let decoded = try JSONDecoder().decode(ServerSettings.self, from: JSONEncoder().encode(settings))

        #expect(decoded == settings)
        #expect(decoded.updating(defaultModelID: ChatModel.ID("gemma4")).appearance == appearance)
    }

    @Test func `changing the theme leaves everything else as it was`() {
        let settings = ServerSettings(ollamaAddress: "https://a.example", voice: "af_heart", defaultModelID: ChatModel.ID("gemma4"))

        let dark = settings.updating(appearance: .dark)

        #expect(dark.appearance == .dark)
        #expect(dark.ollamaAddress == "https://a.example")
        #expect(dark.voice == "af_heart")
        #expect(dark.defaultModelID == ChatModel.ID("gemma4"))
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

struct SearchSourceTests {
    @Test(arguments: [
        ("https://docs.example.com/ps", true),
        ("HTTP://example.com", true),
        ("tel:+15550100", false),
        ("javascript:alert(1)", false),
        ("otherapp://open?item=1", false),
        ("file:///etc/hosts", false),
        ("https:///no-host", false)
    ])
    func `only links to web pages are accepted`(address: String, isAccepted: Bool) throws {
        #expect(SearchSource.isWebLink(try #require(URL(string: address))) == isAccepted)
    }
}

struct MathTransformerTests {
    @Test(arguments: [
        ("x^2 + y^{10}", "x² + y¹⁰"),
        ("a_1 + a_{n+1}", "a₁ + aₙ₊₁"),
        ("\\frac{a}{b}", "a/b"),
        ("\\frac{a+1}{2b}", "(a+1)/2b"),
        ("\\frac{1}{\\sqrt{2}}", "1/(√(2))"),
        ("\\alpha \\leq \\beta \\times \\infty", "α ≤ β × ∞"),
        ("\\left( x \\right) \\to \\text{done}", "( x ) → done"),
        ("x^{ab}", "x^(ab)"),
        ("x^y", "x^y"),
        ("\\sum_{i=1}^{n} i", "∑ᵢ₌₁ⁿ i")
    ])
    func `LaTeX is rewritten as readable text`(latex: String, readable: String) {
        #expect(MathTransformer().readable(latex) == readable)
    }

    @Test(arguments: [
        ("The area is \\(\\pi r^2\\) exactly.", "The area is π r² exactly."),
        ("So $x^2 = 4$ here.", "So x² = 4 here."),
        ("Inline $$a \\neq b$$ too.", "Inline a ≠ b too."),
        ("It costs $5 and $10.", "It costs $5 and $10."),
        ("Pay $20 for x_1 or $30.", "Pay $20 for x_1 or $30."),
        ("No maths here.", "No maths here.")
    ])
    func `only maths between its delimiters is rewritten`(text: String, expected: String) {
        #expect(MathTransformer().readableInline(text) == expected)
    }
}

struct ConversationExporterTests {
    @Test func `a conversation is written out with a title, speakers, files and sources`() throws {
        let source = SearchSource(title: "Docs", url: try #require(URL(string: "https://docs.example/ps")), snippet: "")
        let conversation = Conversation(title: "Loaded models", messages: [
            Message(role: .user, text: "What is loaded?", documents: [AttachedDocument(name: "log.txt", text: "…")]),
            Message(role: .assistant, text: "Nothing.", sources: [source]),
            Message(role: .assistant, text: "")
        ])

        let markdown = ConversationExporter(userLabel: "You", assistantLabel: "Hearth", untitled: "New chat").markdown(for: conversation)

        #expect(markdown == "# Loaded models\n\n**You**\n\n_log.txt_\n\nWhat is loaded?\n\n**Hearth**\n\nNothing.\n\n1. [Docs](https://docs.example/ps)\n")
    }

    @Test func `a conversation without a title is given the fallback`() {
        let markdown = ConversationExporter(userLabel: "You", assistantLabel: "Hearth", untitled: "New chat").markdown(for: Conversation())

        #expect(markdown == "# New chat\n")
    }
}

struct FollowUpTransformerTests {
    @Test func `questions are read one per line without their list markers or quotes`() {
        let answer = """
        Here are some ideas:
        1. How do I unload a model?
        - "What does the UNTIL column mean?"
        * **Can I keep a model loaded for longer?**
        Does it show GPU memory?
        """

        #expect(FollowUpTransformer().questions(from: answer) == [
            "How do I unload a model?",
            "What does the UNTIL column mean?",
            "Can I keep a model loaded for longer?"
        ])
    }

    @Test(arguments: ["", "I have no suggestions.", "Why?", "Sure!\n\nOkay."])
    func `an answer holding no real questions gives none`(answer: String) {
        #expect(FollowUpTransformer().questions(from: answer).isEmpty)
    }

    @Test func `the request quotes the latest question and reply, and is not made before there is a reply`() throws {
        let history = [
            Message(role: .user, text: "Old question"),
            Message(role: .assistant, text: "Old reply"),
            Message(role: .user, text: "What is loaded?"),
            Message(role: .assistant, text: "Nothing is loaded.")
        ]

        let prompt = try #require(FollowUpTransformer().prompt(history: history))

        #expect(prompt.contains("User: What is loaded?"))
        #expect(prompt.contains("Assistant: Nothing is loaded."))
        #expect(!prompt.contains("Old"))
        #expect(FollowUpTransformer().prompt(history: [Message(role: .user, text: "Hello")]) == nil)
    }
}
