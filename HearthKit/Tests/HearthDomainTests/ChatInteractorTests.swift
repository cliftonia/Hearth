import Foundation
@testable import HearthDomain
import Testing

struct ChatInteractorTests {
    struct Fixture {
        let subject: ChatInteractor
        let requests: Recorder<ChatRequest>
        let queries: Recorder<String>
    }

    private static let model = ChatModel(id: ChatModel.ID("gemma4:latest"), canThink: true)
    private static let settings = ServerSettings(ollamaAddress: "https://ollama.example", searchAddress: "https://search.example")

    private func makeTestSubject(
        deltas: [ChatDelta] = [.text("Hello")],
        failure: (any Error & Sendable)? = nil,
        search: @escaping @Sendable (String) async throws -> [SearchSource] = { _ in [] }
    ) -> Fixture {
        let requests = Recorder<ChatRequest>()
        let queries = Recorder<String>()
        let chat = ChatDataProvider(
            fetchModels: { _ in [] },
            streamChat: { _, request in
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
        let searchProvider = SearchDataProvider { _, query in
            queries.record(query)
            return try await search(query)
        }
        let subject = ChatInteractor(chat: chat, search: searchProvider, now: { Date(timeIntervalSince1970: 1_800_000_000) })
        return Fixture(subject: subject, requests: requests, queries: queries)
    }

    private func turn(isSearchEnabled: Bool = false, style: ReplyStyle = .chat, settings: ServerSettings = settings) -> ChatInteractor.Turn {
        ChatInteractor.Turn(
            history: [Message(role: .user, text: "What is loaded?")],
            model: Self.model,
            settings: settings,
            isSearchEnabled: isSearchEnabled,
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
        let fixture = makeTestSubject(deltas: [.thinking("Hm"), .text("Hel"), .text("lo")])

        let events = try await events(fixture.subject.run(turn()))

        #expect(events == [.thinking("Hm"), .text("Hel"), .text("lo")])
        #expect(fixture.queries.values.isEmpty)
    }

    @Test func `search results are reported and handed to the model`() async throws {
        let source = SearchSource(title: "Docs", url: try #require(URL(string: "https://docs.example/ps")), snippet: "Lists models.")
        let fixture = makeTestSubject(search: { _ in Array(repeating: source, count: 9) })

        let events = try await events(fixture.subject.run(turn(isSearchEnabled: true)))

        #expect(events.first == .sources(Array(repeating: source, count: 5)))
        #expect(fixture.queries.values == ["What is loaded?"])
        #expect(fixture.requests.values.first?.messages.first?.text.contains("[5] Docs") == true)
    }

    @Test func `a failed search is reported and the reply still comes`() async throws {
        let fixture = makeTestSubject(search: { _ in throw URLError(.timedOut) })

        let events = try await events(fixture.subject.run(turn(isSearchEnabled: true)))

        #expect(events == [.searchFailed, .text("Hello")])
    }

    @Test func `no search is made without a search server`() async throws {
        let fixture = makeTestSubject()
        let settings = ServerSettings(ollamaAddress: "https://ollama.example")

        _ = try await events(fixture.subject.run(turn(isSearchEnabled: true, settings: settings)))

        #expect(fixture.queries.values.isEmpty)
    }

    @Test func `a spoken turn skips the thinking that would delay it`() async throws {
        let fixture = makeTestSubject()

        _ = try await events(fixture.subject.run(turn(style: .voice)))

        #expect(fixture.requests.values.first?.isThinkingEnabled == false)
    }

    @Test func `a turn without a server fails as not configured`() async {
        let fixture = makeTestSubject()

        await #expect(throws: ChatError.serverNotConfigured) {
            _ = try await events(fixture.subject.run(turn(settings: ServerSettings())))
        }
    }

    @Test func `a connection failure becomes unreachable`() async {
        let fixture = makeTestSubject(deltas: [], failure: URLError(.cannotConnectToHost))

        await #expect(throws: ChatError.unreachable) {
            _ = try await events(fixture.subject.run(turn()))
        }
    }

    @Test func `a title is one clean line`() async throws {
        let fixture = makeTestSubject()

        let title = try await fixture.subject.title(for: "What is loaded?", model: Self.model, settings: Self.settings)

        #expect(title == "Loaded models")
        #expect(fixture.requests.values.first?.isThinkingEnabled == false)
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
