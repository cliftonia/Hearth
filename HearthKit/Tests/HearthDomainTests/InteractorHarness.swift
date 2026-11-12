import Foundation
@testable import HearthDomain

/// A chat interactor wired to scripted replies and searches, with a record of what it asked of them.
enum InteractorHarness {
    /// The interactor under test, with what it sent to the model and what it searched for.
    struct Fixture {
        let subject: ChatInteractor
        let requests: Recorder<ChatRequest>
        let queries: Recorder<String>
        let kinds: Recorder<SearchKind>
    }

    static let model = ChatModel(id: ChatModel.ID("gemma4:latest"), canThink: true, canUseTools: true)
    static let settings = ServerSettings(ollamaAddress: "https://ollama.example", searchAddress: "https://search.example")
    static let source = SearchSource(title: "Docs", url: URL(filePath: "/docs"), snippet: "Lists models.")

    /// - Parameter rounds: What the model streams each time it is called; the last entry repeats.
    static func makeTestSubject(
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

    /// A turn holding one question from the user, with nothing attached.
    static func turn(
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

    /// Every event of a turn, collected once the turn has ended.
    static func events(_ stream: AsyncThrowingStream<ChatInteractor.Event, any Error>) async throws -> [ChatInteractor.Event] {
        var events: [ChatInteractor.Event] = []
        for try await event in stream {
            events.append(event)
        }
        return events
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
