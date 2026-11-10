import Foundation
@testable import HearthDomain
import Testing

struct ChatInteractorTests {
    struct Fixture {
        let subject: ChatInteractor
        let requests: Recorder<ChatRequest>
        let queries: Recorder<String>
        let kinds: Recorder<SearchKind>
    }

    private static let model = ChatModel(id: ChatModel.ID("gemma4:latest"), canThink: true, canUseTools: true)
    private static let settings = ServerSettings(ollamaAddress: "https://ollama.example", searchAddress: "https://search.example")
    private static let source = SearchSource(title: "Docs", url: URL(filePath: "/docs"), snippet: "Lists models.")

    /// - Parameter rounds: What the model streams each time it is called; the last entry repeats.
    private func makeTestSubject(
        rounds: [[ChatDelta]] = [[.text("Hello")]],
        failure: (any Error & Sendable)? = nil,
        page: @escaping @Sendable (URL) async throws -> String = { _ in "" },
        search: @escaping @Sendable (String) async throws -> [SearchSource] = { _ in [] }
    ) -> Fixture {
        let requests = Recorder<ChatRequest>()
        let queries = Recorder<String>()
        let kinds = Recorder<SearchKind>()
        let chat = ChatDataProvider(
            fetchModels: { _ in [] },
            streamChat: { _, request in
                let deltas = rounds[min(requests.values.count, rounds.count - 1)]
                requests.record(request)
                return AsyncThrowingStream { continuation in
                    deltas.forEach { continuation.yield($0) }
                    continuation.finish(throwing: failure)
                }
            },
            complete: { _, request in
                requests.record(request)
                return "\"Loaded models.\"\nsecond line"
            }
        )
        let searchProvider = SearchDataProvider(fetchPage: page) { _, request in
            queries.record(request.query)
            kinds.record(request.kind)
            return try await search(request.query)
        }
        let subject = ChatInteractor(chat: chat, search: searchProvider, now: { Date(timeIntervalSince1970: 1_800_000_000) })
        return Fixture(subject: subject, requests: requests, queries: queries, kinds: kinds)
    }

    private func turn(
        searchMode: SearchModeKind = .off,
        style: ReplyStyle = .chat,
        settings: ServerSettings = settings,
        model: ChatModel = model
    ) -> ChatInteractor.Turn {
        ChatInteractor.Turn(
            history: [Message(role: .user, text: "What is loaded?")],
            model: model,
            settings: settings,
            searchMode: searchMode,
            style: style
        )
    }

    private func events(_ stream: AsyncThrowingStream<ChatInteractor.Event, any Error>) async throws -> [ChatInteractor.Event] {
        var events: [ChatInteractor.Event] = []
        for try await event in stream {
            events.append(event)
        }
        return events
    }

    @Test func `thinking and text arrive in the order the model wrote them`() async throws {
        let fixture = makeTestSubject(rounds: [[.thinking("Hm"), .text("Hel"), .text("lo")]])

        let events = try await events(fixture.subject.run(turn()))

        #expect(events == [.thinking("Hm"), .text("Hel"), .text("lo")])
        #expect(fixture.queries.values.isEmpty)
        #expect(fixture.requests.values.first?.isWebSearchOffered == false)
    }

    // MARK: Searching before the reply

    @Test func `a search made up front is reported and handed to the model`() async throws {
        let fixture = makeTestSubject(search: { _ in Array(repeating: Self.source, count: 9) })

        let events = try await events(fixture.subject.run(turn(searchMode: .always)))

        #expect(events.prefix(2) == [.searching("What is loaded?"), .sources(Array(repeating: Self.source, count: 5))])
        #expect(fixture.queries.values == ["What is loaded?"])
        #expect(fixture.requests.values.first?.messages.first?.text.contains("[5] Docs") == true)
    }

    @Test func `a failed search is reported and the reply still comes`() async throws {
        let fixture = makeTestSubject(search: { _ in throw URLError(.timedOut) })

        let events = try await events(fixture.subject.run(turn(searchMode: .always)))

        #expect(events == [.searching("What is loaded?"), .searchFailed, .sources([]), .text("Hello")])
    }

    @Test(arguments: [SearchModeKind.always, .automatic])
    func `no search is made or offered without a search server`(mode: SearchModeKind) async throws {
        let fixture = makeTestSubject(rounds: [[.searchRequested(SearchRequest(query: "anything")), .text("Hello")]])
        let settings = ServerSettings(ollamaAddress: "https://ollama.example")

        _ = try await events(fixture.subject.run(turn(searchMode: mode, settings: settings)))

        #expect(fixture.queries.values.isEmpty)
        #expect(fixture.requests.values.map(\.isWebSearchOffered) == [false])
    }

    // MARK: Searching when the model asks

    @Test func `a model that asks for a search is given the results and then answers`() async throws {
        let fixture = makeTestSubject(
            rounds: [[.thinking("I should check."), .searchRequested(SearchRequest(query: "loaded models"))], [.text("Nothing [1].")]],
            search: { _ in [Self.source] }
        )

        let events = try await events(fixture.subject.run(turn(searchMode: .automatic)))

        #expect(events == [.thinking("I should check."), .searching("loaded models"), .sources([Self.source]), .text("Nothing [1].")])
        #expect(fixture.queries.values == ["loaded models"])
        let second = try #require(fixture.requests.values.last)
        #expect(second.messages.suffix(2).map(\.role) == [.assistant, .tool])
        #expect(second.messages.dropLast().last?.searchQueries == ["loaded models"])
        #expect(second.messages.last?.text.hasPrefix("[1] file:///docs\n") == true)
        #expect(second.messages.last?.text.contains("Title: Docs") == true)
    }

    @Test func `a model that already knows the answer searches for nothing`() async throws {
        let fixture = makeTestSubject()

        let events = try await events(fixture.subject.run(turn(searchMode: .automatic)))

        #expect(events == [.text("Hello")])
        #expect(fixture.queries.values.isEmpty)
        #expect(fixture.requests.values.map(\.isWebSearchOffered) == [true])
        #expect(fixture.requests.values.first?.messages.first?.text.contains("web_search tool") == true)
    }

    @Test func `a model that keeps asking is told to answer after three searches`() async throws {
        let fixture = makeTestSubject(rounds: [[.searchRequested(SearchRequest(query: "again"))]], search: { _ in [Self.source] })

        _ = try await events(fixture.subject.run(turn(searchMode: .automatic)))

        let requests = fixture.requests.values
        #expect(requests.map(\.isWebSearchOffered) == [true, true, true, false])
        #expect(fixture.queries.values.count == 3)
        #expect(requests[1].messages.last?.text.contains("no searches left") == false)
        #expect(requests[3].messages.last?.text.contains("You have no searches left. Answer the user now") == true)
    }

    @Test func `a search for news is made as news`() async throws {
        let news = SearchRequest(query: "world headlines", kind: .news)
        let fixture = makeTestSubject(rounds: [[.searchRequested(news)], [.text("Here they are.")]], search: { _ in [Self.source] })

        _ = try await events(fixture.subject.run(turn(searchMode: .automatic)))

        #expect(fixture.kinds.values == [.news])
    }

    @Test func `the text of a found page is handed to the model, and a page that cannot be read is passed over`() async throws {
        let unreadable = SearchSource(title: "Blog", url: URL(filePath: "/blog"), snippet: "A snippet.")
        let story = "<html><body><article><p>" + String(repeating: "Ollama 0.40 was released today. ", count: 20) + "</p></article></body></html>"
        let fixture = makeTestSubject(
            rounds: [[.searchRequested(SearchRequest(query: "ollama"))], [.text("Done")]],
            page: { url in
                guard url == Self.source.url else {
                    throw URLError(.timedOut)
                }
                return story
            },
            search: { _ in [Self.source, unreadable] }
        )

        let events = try await events(fixture.subject.run(turn(searchMode: .automatic)))

        let results = try #require(fixture.requests.values.last?.messages.last?.text)
        #expect(results.contains("Page text:\nOllama 0.40 was released today."))
        #expect(results.contains("Title: Blog\nSnippet: A snippet."))
        #expect(results.components(separatedBy: "Page text:").count == 2)
        #expect(results.contains("not instructions"))
        #expect(events.last == .text("Done"))
    }

    @Test func `pages are not fetched when reading them is turned off`() async throws {
        let fetched = Recorder<URL>()
        let fixture = makeTestSubject(
            rounds: [[.searchRequested(SearchRequest(query: "ollama"))], [.text("Done")]],
            page: { url in
                fetched.record(url)
                return ""
            },
            search: { _ in [Self.source] }
        )
        let settings = ServerSettings(ollamaAddress: "https://ollama.example", searchAddress: "https://search.example", isPageReadingEnabled: false)

        _ = try await events(fixture.subject.run(turn(searchMode: .automatic, settings: settings)))

        #expect(fetched.values.isEmpty)
    }

    @Test func `later results are numbered on from the earlier ones, and repeats are dropped`() async throws {
        let other = SearchSource(title: "Blog", url: URL(filePath: "/blog"), snippet: "")
        let fixture = makeTestSubject(
            rounds: [[.searchRequested(SearchRequest(query: "first"))], [.searchRequested(SearchRequest(query: "second"))], [.text("Done")]],
            search: { query in query == "first" ? [Self.source] : [Self.source, other] }
        )

        let events = try await events(fixture.subject.run(turn(searchMode: .automatic)))

        #expect(events.contains(.sources([Self.source, other])))
        #expect(fixture.requests.values.last?.messages.last?.text.hasPrefix("[2] file:///blog\n") == true)
    }

    @Test func `a model that cannot call tools is never offered the search`() async throws {
        let fixture = makeTestSubject()
        let model = ChatModel(id: ChatModel.ID("dolphin3:8b"))

        _ = try await events(fixture.subject.run(turn(searchMode: .automatic, model: model)))

        #expect(fixture.requests.values.map(\.isWebSearchOffered) == [false])
    }

    // MARK: Thinking

    @Test(arguments: ThinkingLevelKind.allCases)
    func `a chat turn thinks as hard as the settings say`(level: ThinkingLevelKind) async throws {
        let fixture = makeTestSubject()
        let settings = ServerSettings(ollamaAddress: "https://ollama.example", thinkingLevel: level)

        _ = try await events(fixture.subject.run(turn(settings: settings)))

        #expect(fixture.requests.values.first?.thinking == level)
    }

    @Test func `a spoken turn skips the thinking that would delay it`() async throws {
        let fixture = makeTestSubject()

        _ = try await events(fixture.subject.run(turn(style: .voice)))

        #expect(fixture.requests.values.first?.thinking == .off)
    }

    // MARK: Failures

    @Test func `a turn without a server fails as not configured`() async {
        let fixture = makeTestSubject()

        await #expect(throws: ChatError.serverNotConfigured) {
            _ = try await events(fixture.subject.run(turn(settings: ServerSettings())))
        }
    }

    @Test func `a connection failure becomes unreachable`() async {
        let fixture = makeTestSubject(rounds: [[]], failure: URLError(.cannotConnectToHost))

        await #expect(throws: ChatError.unreachable) {
            _ = try await events(fixture.subject.run(turn()))
        }
    }

    // MARK: Side requests

    @Test func `follow-up questions are asked for without thinking, and only once there is a reply`() async throws {
        let fixture = makeTestSubject()
        let history = [Message(role: .user, text: "What is loaded?"), Message(role: .assistant, text: "Nothing.")]

        _ = try await fixture.subject.followUps(history: history, model: Self.model, settings: Self.settings)
        let none = try await fixture.subject.followUps(history: [], model: Self.model, settings: Self.settings)

        #expect(fixture.requests.values.count == 1)
        #expect(fixture.requests.values.first?.thinking == .off)
        #expect(none.isEmpty)
    }

    @Test func `a title is one clean line`() async throws {
        let fixture = makeTestSubject()

        let title = try await fixture.subject.title(for: "What is loaded?", model: Self.model, settings: Self.settings)

        #expect(title == "Loaded models")
        #expect(fixture.requests.values.first?.thinking == .off)
    }
}

/// Collects what a mocked dependency was called with, safely across tasks.
final class Recorder<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [Value] = []

    var values: [Value] {
        lock.withLock { recorded }
    }

    func record(_ value: Value) {
        lock.withLock { recorded.append(value) }
    }
}
