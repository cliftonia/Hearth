import Foundation
@testable import HearthDomain
import Testing

/// How research is carried out: its steps in order, what it skips, when it gives up, and how it stops.
struct ResearchInteractorTests {
    private typealias Harness = ResearchHarness

    @Test func `the steps are reported in order, and the report is written from the pages noted`() async throws {
        let fixture = Harness.makeTestSubject()

        let events = try await Harness.events(fixture.subject.run(Harness.request))

        let expectedSteps: [ResearchStepKind] = [
            .planning,
            .searching(number: 1, total: 2), .searching(number: 2, total: 2),
            .reading(number: 1, total: 4), .reading(number: 2, total: 4), .reading(number: 3, total: 4), .reading(number: 4, total: 4),
            .takingNotes(number: 1, total: 4), .takingNotes(number: 2, total: 4), .takingNotes(number: 3, total: 4),
            .takingNotes(number: 4, total: 4),
            .checking,
            .writing
        ]
        // The searches take turns, so the pages are numbered alpha1, beta1, alpha2, beta2.
        let sources = ["alpha1", "beta1", "alpha2", "beta2"].map(Harness.source)
        #expect(Harness.steps(in: events) == expectedSteps)
        #expect(fixture.queries.values == ["alpha", "beta"])
        #expect(Set(fixture.fetched.values) == Set(sources.map(\.url)))
        #expect(events.contains(.sources(sources)))
        #expect(events.suffix(3) == [
            .text("Summary [1]. "),
            .text("More [2]."),
            .finished(ResearchReport(text: "Summary [1]. More [2].", sources: Array(sources.prefix(2))))
        ])
    }

    @Test func `every request goes to the chat's own model, with tools closed and thinking only for the report`() async throws {
        let fixture = Harness.makeTestSubject()

        _ = try await Harness.events(fixture.subject.run(Harness.request))

        let requests = fixture.requests.values
        // One plan, four pages noted, one check for gaps, one report.
        #expect(requests.count == 7)
        #expect(requests.allSatisfy { $0.model == Harness.model && !$0.isWebSearchOffered && !$0.isMemoryOffered })
        #expect(requests.dropLast().allSatisfy { $0.thinking == .off })
        #expect(requests.last?.thinking == .high)
        let reportPrompt = try #require(requests.last?.messages.last?.text)
        #expect(reportPrompt.contains("[1] alpha1 (alpha1.example)"))
        #expect(reportPrompt.contains("[4] beta2 (beta2.example)"))
    }

    @Test(arguments: ["", #"{"queries": []}"#, #"{"queries": [""]}"#, "{\"queries\": [\"heat"])
    func `a plan that cannot be read falls back to searching for the question itself`(plan: String) async throws {
        var script = Harness.Script()
        script.plan = plan
        var web = Harness.Web()
        web.search = { _ in [Harness.source("found")] }
        let fixture = Harness.makeTestSubject(script: script, web: web)

        _ = try await Harness.events(fixture.subject.run(Harness.request))

        #expect(fixture.queries.values == [Harness.question])
    }

    @Test func `a page that fails, and a page with nothing relevant, are passed over and take no number`() async throws {
        var script = Harness.Script()
        script.note = { request in
            if request.messages.last?.text.contains("\"beta1\"") == true {
                return "NOTHING RELEVANT"
            }
            return "- A fact."
        }
        var web = Harness.Web()
        web.page = { url in
            if url == Harness.source("alpha1").url {
                throw URLError(.timedOut)
            }
            return Harness.html
        }
        let fixture = Harness.makeTestSubject(script: script, web: web)

        let events = try await Harness.events(fixture.subject.run(Harness.request))

        let noted = ["alpha2", "beta2"].map(Harness.source)
        #expect(events.contains(.sources(noted)))
        #expect(events.last == .finished(ResearchReport(text: "Summary [1]. More [2].", sources: noted)))
        #expect(Harness.steps(in: events).contains(.takingNotes(number: 3, total: 3)))
    }

    @Test func `addresses that are not public web pages are never fetched`() async throws {
        var web = Harness.Web()
        web.search = { _ in
            ["http://plain.example/a", "https://nas.local/b", "https://box.tailnet.ts.net/c", "https://192.168.1.4/d", "https://fine.example/e"]
                .compactMap { URL(string: $0) }
                .map { SearchSource(title: "Page", url: $0, snippet: "") }
        }
        let fixture = Harness.makeTestSubject(web: web)

        _ = try await Harness.events(fixture.subject.run(Harness.request))

        #expect(fixture.fetched.values.map(\.absoluteString) == ["https://fine.example/e"])
    }

    @Test func `a gap in the notes is searched for once more, within its own bounds`() async throws {
        var script = Harness.Script()
        script.gap = #"{"queries": ["gamma", "delta", "epsilon", "zeta"]}"#
        var web = Harness.Web()
        web.search = { query in (1...3).map { Harness.source("\(query)\($0)") } }
        let fixture = Harness.makeTestSubject(script: script, web: web)

        let events = try await Harness.events(fixture.subject.run(Harness.request))

        // Two planned searches, then at most three more; six pages from the plan, then at most four more.
        #expect(fixture.queries.values == ["alpha", "beta", "gamma", "delta", "epsilon"])
        #expect(fixture.fetched.values.count == 6 + ResearchLimits.maximumFollowUpSources)
        let steps = Harness.steps(in: events)
        #expect(steps.filter { $0 == .checking }.count == 1)
        #expect(steps.contains(.searching(number: 3, total: 3)))
        #expect(steps.last == .writing)
        let gapRequests = fixture.requests.values.filter { Harness.step(of: $0) == .gap }
        #expect(gapRequests.count == 1)
    }

    @Test func `no more pages are chosen than the bound, however much is found`() async throws {
        var script = Harness.Script()
        script.plan = #"{"queries": ["a", "b", "c", "d", "e", "f", "g"]}"#
        var web = Harness.Web()
        web.search = { query in (1...9).map { Harness.source("\(query)\($0)") } }
        let fixture = Harness.makeTestSubject(script: script, web: web)

        _ = try await Harness.events(fixture.subject.run(Harness.request))

        #expect(fixture.queries.values.count == ResearchLimits.maximumQueries)
        #expect(fixture.fetched.values.count == ResearchLimits.maximumSources)
    }

    @Test func `only a few pages are fetched at once`() async throws {
        let gauge = Gauge()
        var web = Harness.Web()
        web.search = { query in (1...6).map { Harness.source("\(query)\($0)") } }
        web.page = { _ in
            gauge.enter()
            defer { gauge.leave() }
            try await Task.sleep(for: .milliseconds(20))
            return Harness.html
        }
        let fixture = Harness.makeTestSubject(web: web)

        _ = try await Harness.events(fixture.subject.run(Harness.request))

        #expect(gauge.ended == ResearchLimits.maximumSources)
        #expect(gauge.peak <= ResearchLimits.maximumConcurrentPageFetches)
        #expect(gauge.peak > 1)
    }

    @Test func `a page that does not answer in time is given up on, and the rest are read`() async throws {
        var web = Harness.Web()
        web.pageTimeout = .milliseconds(100)
        web.page = { url in
            if url == Harness.source("alpha1").url {
                try await Task.sleep(for: .seconds(60))
            }
            return Harness.html
        }
        let fixture = Harness.makeTestSubject(web: web)

        let events = try await Harness.events(fixture.subject.run(Harness.request))

        #expect(events.contains(.sources(["beta1", "alpha2", "beta2"].map(Harness.source))))
    }
}

/// When research gives up without writing anything, and how it is stopped.
struct ResearchInteractorFailureTests {
    private typealias Harness = ResearchHarness

    /// What goes wrong on the way to a report.
    enum TroubleKind: CaseIterable {
        case everySearchFails
        case nothingIsFound
        case noPageCanBeRead
        case everyPageIsEmpty
        case noPageIsRelevant

        /// The plan alone, or the plan and a note asked for on each of the four pages.
        var expectedRequestCount: Int {
            switch self {
            case .everySearchFails, .nothingIsFound, .noPageCanBeRead, .everyPageIsEmpty:
                1
            case .noPageIsRelevant:
                5
            }
        }

        var expected: ResearchError {
            switch self {
            case .everySearchFails:
                .searchFailed
            case .nothingIsFound:
                .nothingFound
            case .noPageCanBeRead, .everyPageIsEmpty:
                .nothingReadable
            case .noPageIsRelevant:
                .nothingRelevant
            }
        }
    }

    @Test(arguments: TroubleKind.allCases)
    func `with nothing to write from, it says what came to nothing and writes no report`(trouble: TroubleKind) async throws {
        var script = Harness.Script()
        var web = Harness.Web()
        switch trouble {
        case .everySearchFails:
            web.search = { _ in throw URLError(.cannotFindHost) }
        case .nothingIsFound:
            web.search = { _ in [] }
        case .noPageCanBeRead:
            web.page = { _ in throw URLError(.badServerResponse) }
        case .everyPageIsEmpty:
            web.page = { _ in "<html><body><p>Enable JavaScript.</p></body></html>" }
        case .noPageIsRelevant:
            script.note = { _ in "NOTHING RELEVANT" }
        }
        let fixture = Harness.makeTestSubject(script: script, web: web)

        await #expect(throws: trouble.expected) {
            _ = try await Harness.events(fixture.subject.run(Harness.request))
        }
        // The report is the one streamed request, and it was never made; nor was the check for gaps.
        #expect(fixture.requests.values.allSatisfy { Harness.step(of: $0) != .gap })
        #expect(fixture.requests.values.count == trouble.expectedRequestCount)
    }

    @Test func `one search failing is no reason to stop`() async throws {
        var web = Harness.Web()
        web.search = { query in
            if query == "alpha" {
                throw URLError(.timedOut)
            }
            return [Harness.source("beta1")]
        }
        let fixture = Harness.makeTestSubject(web: web)

        let events = try await Harness.events(fixture.subject.run(Harness.request))

        #expect(events.contains(.sources([Harness.source("beta1")])))
    }

    @Test func `without a search address there is no research, and nothing is asked of the model`() async throws {
        let fixture = Harness.makeTestSubject()
        let settings = ServerSettings(ollamaAddress: "https://ollama.example")
        let request = ResearchInteractor.Request(question: Harness.question, model: Harness.model, settings: settings)

        await #expect(throws: ResearchError.searchNotConfigured) {
            _ = try await Harness.events(fixture.subject.run(request))
        }
        #expect(fixture.requests.values.isEmpty)
    }

    @Test func `the model failing on every page is the chat server's failure, not an empty web`() async throws {
        var script = Harness.Script()
        script.note = { _ in throw URLError(.networkConnectionLost) }
        let fixture = Harness.makeTestSubject(script: script)

        await #expect(throws: ChatError.unreachable) {
            _ = try await Harness.events(fixture.subject.run(Harness.request))
        }
    }

    @Test func `the model failing on one page only loses that page`() async throws {
        var script = Harness.Script()
        script.note = { request in
            if request.messages.last?.text.contains("\"alpha1\"") == true {
                throw URLError(.networkConnectionLost)
            }
            return "- A fact."
        }
        let fixture = Harness.makeTestSubject(script: script)

        let events = try await Harness.events(fixture.subject.run(Harness.request))

        #expect(events.contains(.sources(["beta1", "alpha2", "beta2"].map(Harness.source))))
    }

    @Test func `stopping cancels the pages being fetched and asks nothing more of the model`() async throws {
        let gauge = Gauge()
        var web = Harness.Web()
        web.page = { _ in
            gauge.enter()
            defer { gauge.leave() }
            // A page that would take a minute, unless the fetch is cancelled.
            try await Task.sleep(for: .seconds(60))
            return Harness.html
        }
        let fixture = Harness.makeTestSubject(web: web)
        let stream = fixture.subject.run(Harness.request)
        let clock = ContinuousClock()
        let startedAt = clock.now

        let consumer = Task {
            var steps: [ResearchStepKind] = []
            for try await event in stream {
                if case .step(let step) = event {
                    steps.append(step)
                }
                if case .step(.reading) = event {
                    // Give the fetches a moment to begin, then stop, as the Stop button does.
                    try? await Task.sleep(for: .milliseconds(100))
                    withUnsafeCurrentTask { $0?.cancel() }
                }
            }
            return steps
        }
        let steps = try await consumer.value
        // The fetches end because they were cancelled, long before they would have finished or timed out.
        while gauge.ended < gauge.peak, clock.now - startedAt < .seconds(4) {
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(clock.now - startedAt < .seconds(4))
        #expect(gauge.peak == 4)
        #expect(gauge.ended == 4)
        #expect(steps.last == .reading(number: 1, total: 4))
        // Only the plan was ever asked for.
        #expect(fixture.requests.values.count == 1)
    }
}
