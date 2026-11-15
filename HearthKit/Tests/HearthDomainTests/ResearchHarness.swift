import Foundation
@testable import HearthDomain

/// A research interactor wired to a scripted model, search and web, with a record of what it asked of them.
enum ResearchHarness {
    /// The interactor under test, with what it sent to the model, what it searched for and which pages it fetched.
    struct Fixture {
        let subject: ResearchInteractor
        let requests: Recorder<ChatRequest>
        let queries: Recorder<String>
        let fetched: Recorder<URL>
    }

    /// What the model answers at each step.
    struct Script: Sendable {
        var plan = #"{"queries": ["alpha", "beta"]}"#
        var gap = #"{"queries": []}"#
        /// The notes for a page, given the request that showed it.
        var note: @Sendable (ChatRequest) async throws -> String = { _ in "- A fact." }
        var report: [ChatDelta] = [.text("Summary [1]. "), .text("More [2].")]
    }

    /// The model's side of things beyond its answers: what the search finds and what the web serves.
    struct Web: Sendable {
        var search: @Sendable (String) async throws -> [SearchSource] = { query in
            (1...2).map { ResearchHarness.source("\(query)\($0)") }
        }
        var page: @Sendable (URL) async throws -> String = { _ in ResearchHarness.html }
        var pageTimeout = Duration.seconds(5)
    }

    static let question = "How do heat pumps work?"
    static let model = ChatModel(id: ChatModel.ID("gemma4:latest"), canThink: true, canUseTools: true)
    static let settings = ServerSettings(ollamaAddress: "https://ollama.example", searchAddress: "https://search.example", thinkingLevel: .high)
    static let request = ResearchInteractor.Request(question: question, model: model, settings: settings)
    /// A page with enough text to be worth reading.
    static let html = "<html><body><p>" + String(repeating: "Heat pumps move heat. ", count: 20) + "</p></body></html>"

    /// A page on a site of its own, named after the site.
    static func source(_ name: String) -> SearchSource {
        SearchSource(title: name, url: URL(string: "https://\(name).example/page") ?? URL(filePath: "/"), snippet: "")
    }

    static func makeTestSubject(script: Script = Script(), web: Web = Web()) -> Fixture {
        let requests = Recorder<ChatRequest>()
        let queries = Recorder<String>()
        let fetched = Recorder<URL>()
        let chat = ChatDataProvider(
            fetchModels: { _ in [] },
            streamChat: { _, request in
                requests.record(request)
                return AsyncThrowingStream { continuation in
                    script.report.forEach { continuation.yield($0) }
                    continuation.finish()
                }
            },
            complete: { _, request in
                requests.record(request)
                switch step(of: request) {
                case .plan:
                    return script.plan
                case .gap, .report:
                    return script.gap
                case .note:
                    return try await script.note(request)
                }
            }
        )
        let search = SearchDataProvider(
            fetchPage: { url in
                fetched.record(url)
                return try await web.page(url)
            },
            search: { _, request in
                queries.record(request.query)
                return try await web.search(request.query)
            }
        )
        let subject = ResearchInteractor(chat: chat, search: search, pageTimeout: web.pageTimeout, now: { Date(timeIntervalSince1970: 1_800_000_000) })
        return Fixture(subject: subject, requests: requests, queries: queries, fetched: fetched)
    }

    /// Which of the short requests one is, told by how its prompt begins.
    enum StepKind {
        case plan
        case note
        case gap
        case report
    }

    static func step(of request: ChatRequest) -> StepKind {
        let text = request.messages.last?.text ?? ""
        if text.hasPrefix("Plan the web searches") {
            return .plan
        }
        if text.hasPrefix("You are taking notes") {
            return .note
        }
        return text.hasPrefix("Write a research report") ? .report : .gap
    }

    /// Every event of a run, collected once it has ended.
    static func events(_ stream: AsyncThrowingStream<ResearchInteractor.Event, any Error>) async throws -> [ResearchInteractor.Event] {
        var events: [ResearchInteractor.Event] = []
        for try await event in stream {
            events.append(event)
        }
        return events
    }

    /// The steps among the events, in order.
    static func steps(in events: [ResearchInteractor.Event]) -> [ResearchStepKind] {
        events.compactMap { event in
            if case .step(let step) = event {
                return step
            }
            return nil
        }
    }
}

/// Counts how many pieces of work are under way at once, safely across tasks.
final class Gauge: @unchecked Sendable {
    private let lock = NSLock()
    private var current = 0
    private var highest = 0
    private var endedCount = 0

    var peak: Int { lock.withLock { highest } }
    var ended: Int { lock.withLock { endedCount } }

    func enter() {
        lock.withLock {
            current += 1
            highest = max(highest, current)
        }
    }

    func leave() {
        lock.withLock {
            current -= 1
            endedCount += 1
        }
    }
}
