import Foundation

// Searching, reading the pages found and taking notes on them: the part of research that is run once for the
// plan and, at most, once more for what was missing.
extension ResearchInteractor {
    /// A page that was read, with the text taken from it.
    private struct Page: Sendable {
        let source: SearchSource
        let text: String
    }

    /// A page that did not answer in time.
    private struct TimedOut: Error {}

    /// Makes the searches, chooses up to `limit` new pages among what they find, reads them and takes notes.
    /// A search or a page that fails is passed over; only being stopped, or the model failing on every page, ends the run.
    func gather(_ queries: [String], limit: Int, in run: Run, findings: inout Findings, report: (Event) -> Void) async throws {
        var results: [[SearchSource]] = []
        for (index, query) in queries.enumerated() {
            report(.step(.searching(number: index + 1, total: queries.count)))
            findings.searchesMade += 1
            do {
                results.append(try await search.search(run.searchURL, SearchRequest(query: query)))
            } catch {
                try Task.checkCancellation()
                findings.searchesFailed += 1
                // Only that it failed is logged: an error may carry the address or the words searched for.
                logger.notice("A research search failed")
            }
        }
        let fresh = ResearchSourceSelector().select(from: results, limit: limit, taken: findings.chosen, isReadable: isReadable)
        findings.chosen += fresh
        let pages = try await read(fresh, report: report)
        findings.pagesRead += pages.count
        let texts = try await takeNotes(on: pages, in: run, report: report)
        findings.modelRequests += pages.count
        for (page, text) in zip(pages, texts) {
            if let text {
                findings.notes.append(ResearchNote(number: findings.notes.count + 1, source: page.source, text: text))
            }
        }
    }

    /// Fetches the pages, a few at a time, and reduces each to its text. A page that fails, is refused, takes
    /// too long or holds next to nothing is left out.
    private func read(_ sources: [SearchSource], report: (Event) -> Void) async throws -> [Page] {
        guard !sources.isEmpty else {
            return []
        }
        let fetchPage = search.fetchPage
        let timeout = pageTimeout
        report(.step(.reading(number: 1, total: sources.count)))
        let pages = try await Self.concurrently(
            sources,
            limit: ResearchLimits.maximumConcurrentPageFetches,
            onEachDone: { done in
                if done < sources.count {
                    report(.step(.reading(number: done + 1, total: sources.count)))
                }
            },
            work: { source -> Page? in
                guard let html = try? await Self.withTimeout(timeout, { try await fetchPage(source.url) }) else {
                    return nil
                }
                let text = HTMLTextTransformer().text(from: html, maximumLength: ResearchLimits.maximumPageCharacters)
                return text.count >= ResearchLimits.minimumPageCharacters ? Page(source: source, text: text) : nil
            }
        )
        return pages.compactMap { $0 }
    }

    /// Asks the model for notes on each page, a few at a time. The answer for a page is `nil` when it held
    /// nothing relevant, or when the model could not be asked about it; if it could not be asked about any, that
    /// is the chat server failing, and its error is thrown.
    private func takeNotes(on pages: [Page], in run: Run, report: (Event) -> Void) async throws -> [String?] {
        guard !pages.isEmpty else {
            return []
        }
        let complete = chat.complete
        let prompts = run.prompts
        let (chatURL, model) = (run.chatURL, run.request.model)
        report(.step(.takingNotes(number: 1, total: pages.count)))
        let answers = try await Self.concurrently(
            pages,
            limit: ResearchLimits.maximumConcurrentNoteRequests,
            onEachDone: { done in
                if done < pages.count {
                    report(.step(.takingNotes(number: done + 1, total: pages.count)))
                }
            },
            work: { page -> Result<String?, any Error> in
                let messages = prompts.noteMessages(for: page.source, pageText: page.text)
                do {
                    let answer = try await complete(chatURL, ChatRequest(model: model, messages: messages, thinking: .off))
                    return .success(prompts.note(from: answer))
                } catch {
                    return .failure(error)
                }
            }
        )
        let failures = answers.compactMap { answer -> (any Error)? in
            if case .failure(let error) = answer {
                return error
            }
            return nil
        }
        if let failure = failures.first, failures.count == answers.count {
            throw failure
        }
        return answers.map { (try? $0.get()) ?? nil }
    }

    // MARK: Bounded work

    /// Runs `work` over the items with at most `limit` under way at once, and returns the outcomes in the items'
    /// order. Being cancelled stops what is under way and throws.
    private static func concurrently<Item: Sendable, Output: Sendable>(
        _ items: [Item],
        limit: Int,
        onEachDone: (Int) -> Void,
        work: @escaping @Sendable (Item) async -> Output
    ) async throws -> [Output] {
        try await withThrowingTaskGroup(of: (Int, Output).self) { group in
            var outputs = [Output?](repeating: nil, count: items.count)
            var next = 0
            var done = 0
            while next < min(max(limit, 1), items.count) {
                let (index, item) = (next, items[next])
                group.addTask { (index, await work(item)) }
                next += 1
            }
            while let (index, output) = try await group.next() {
                outputs[index] = output
                done += 1
                try Task.checkCancellation()
                onEachDone(done)
                if next < items.count {
                    let (index, item) = (next, items[next])
                    group.addTask { (index, await work(item)) }
                    next += 1
                }
            }
            try Task.checkCancellation()
            return outputs.compactMap { $0 }
        }
    }

    /// The outcome of `work`, unless it takes longer than `timeout`, in which case it is cancelled and this throws.
    private static func withTimeout<Output: Sendable>(
        _ timeout: Duration,
        _ work: @escaping @Sendable () async throws -> Output
    ) async throws -> Output {
        try await withThrowingTaskGroup(of: Output.self) { group in
            group.addTask(operation: work)
            group.addTask {
                try await Task.sleep(for: timeout)
                throw TimedOut()
            }
            defer { group.cancelAll() }
            guard let first = try await group.next() else {
                throw TimedOut()
            }
            return first
        }
    }
}
