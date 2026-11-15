import Foundation
import HearthCore
import HearthData
import os

/// Researches a question: plans searches, reads the pages they find, takes notes on each, looks once more for
/// what is missing, and has the model write a report that cites its sources.
///
/// Everything is asked of the chat's own model through the same provider a reply uses, so no second model is
/// loaded. Pages are read through the same provider a search's pages are, and so under the same rule about
/// which addresses may be read. The bounds on all of it are in `ResearchLimits`.
public final class ResearchInteractor: Sendable {
    /// Something that happened during research, reported in the order it happened.
    public enum Event: Sendable, Equatable {
        /// What is being done now.
        case step(ResearchStepKind)
        /// The pages the report is being written from, in the order of the numbers it cites them by.
        case sources([SearchSource])
        /// More of the model's reasoning as it writes.
        case thinking(String)
        /// More of the report.
        case text(String)
        /// The report as it is to be kept: its citations checked against its sources, and the sources cut to those cited.
        case finished(ResearchReport)
    }

    /// What one piece of research needs: the question, what was said before it, and the model to ask.
    public struct Request: Sendable {
        public let question: String
        /// The conversation before the question, given to the model as background.
        public let context: [Message]
        public let model: ChatModel
        public let settings: ServerSettings

        public init(question: String, context: [Message] = [], model: ChatModel, settings: ServerSettings) {
            self.question = question
            self.context = context
            self.model = model
            self.settings = settings
        }
    }

    let chat: ChatDataProvider
    let search: SearchDataProvider
    /// Whether a page at this address could be read at all, judged by its form; one that could not is never chosen.
    let isReadable: @Sendable (URL) -> Bool
    let pageTimeout: Duration
    let now: @Sendable () -> Date
    let logger = Logger(for: ResearchInteractor.self)

    public init(
        chat: ChatDataProvider,
        search: SearchDataProvider,
        isReadable: @escaping @Sendable (URL) -> Bool = { PageAddressPolicy.isAllowedForm($0) },
        pageTimeout: Duration = ResearchLimits.pageTimeout,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.chat = chat
        self.search = search
        self.isReadable = isReadable
        self.pageTimeout = pageTimeout
        self.now = now
    }

    /// Runs the research, reporting each event as it happens. Dropping the stream cancels all of it: the search,
    /// every page being fetched and every request to the model.
    public func run(_ request: Request) -> AsyncThrowingStream<Event, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await self.research(request) { continuation.yield($0) }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: ChatError.remapping(error))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

// MARK: - The steps

extension ResearchInteractor {
    /// Where one run sends its requests, and how it words them.
    struct Run {
        let request: Request
        let chatURL: URL
        let searchURL: URL
        let prompts: ResearchPromptBuilder
    }

    /// What a run has gathered so far, and what it has cost.
    struct Findings {
        /// Every page chosen to be read, whether or not it could be.
        var chosen: [SearchSource] = []
        var notes: [ResearchNote] = []
        var pagesRead = 0
        var searchesMade = 0
        var searchesFailed = 0
        var modelRequests = 0
    }

    private func research(_ request: Request, report: (Event) -> Void) async throws {
        guard let chatURL = request.settings.ollamaURL else {
            throw ChatError.serverNotConfigured
        }
        guard let searchURL = request.settings.searchURL else {
            throw ResearchError.searchNotConfigured
        }
        let startedAt = now()
        let prompts = ResearchPromptBuilder(question: request.question, context: request.context, now: startedAt)
        let run = Run(request: request, chatURL: chatURL, searchURL: searchURL, prompts: prompts)
        var findings = Findings()

        report(.step(.planning))
        let planned = try await ask(prompts.planMessages(), in: run, findings: &findings)
        let queries = ResearchQueryParser().plan(from: planned, question: request.question)
        try await gather(queries, limit: ResearchLimits.maximumSources, in: run, findings: &findings, report: report)
        try Self.checkSomethingWasLearned(findings)

        report(.step(.checking))
        let followUps = await followUpQueries(in: run, findings: &findings)
        try Task.checkCancellation()
        if !followUps.isEmpty {
            try await gather(followUps, limit: ResearchLimits.maximumFollowUpSources, in: run, findings: &findings, report: report)
        }

        let notes = ResearchPromptBuilder.fitting(findings.notes)
        let sources = notes.map(\.source)
        report(.sources(sources))
        report(.step(.writing))
        let text = try await write(from: notes, in: run, report: report)
        findings.modelRequests += 1
        report(.finished(ResearchCitationTransformer().tidy(text, sources: sources)))
        let seconds = Int(now().timeIntervalSince(startedAt).rounded())
        // Counts only: nothing of the question, the pages or their addresses is logged.
        logger.info(
            """
            Research finished in \(seconds, privacy: .public)s: \(findings.searchesMade, privacy: .public) searches, \
            \(findings.chosen.count, privacy: .public) pages chosen, \(findings.pagesRead, privacy: .public) read, \
            \(notes.count, privacy: .public) noted, \(findings.modelRequests, privacy: .public) model requests
            """
        )
    }

    /// Research that has learned nothing stops here, saying which step came to nothing, and writes no report.
    private static func checkSomethingWasLearned(_ findings: Findings) throws {
        guard findings.notes.isEmpty else {
            return
        }
        if findings.searchesMade > 0, findings.searchesFailed == findings.searchesMade {
            throw ResearchError.searchFailed
        }
        if findings.chosen.isEmpty {
            throw ResearchError.nothingFound
        }
        throw findings.pagesRead == 0 ? ResearchError.nothingReadable : ResearchError.nothingRelevant
    }

    /// One short request to the model, answered in full.
    private func ask(_ messages: [PromptMessage], in run: Run, findings: inout Findings) async throws -> String {
        findings.modelRequests += 1
        return try await chat.complete(run.chatURL, ChatRequest(model: run.request.model, messages: messages, thinking: .off))
    }

    /// The searches worth making to fill a gap in the notes; none when the notes are enough. Looking once more is
    /// a nicety, so a failure here only means that the report is written from what there is.
    private func followUpQueries(in run: Run, findings: inout Findings) async -> [String] {
        guard let answer = try? await ask(run.prompts.gapMessages(notes: findings.notes), in: run, findings: &findings) else {
            return []
        }
        return ResearchQueryParser().queries(from: answer, limit: ResearchLimits.maximumFollowUpQueries, allowsLines: false)
    }

    /// Streams the report and returns the whole of it.
    private func write(from notes: [ResearchNote], in run: Run, report: (Event) -> Void) async throws -> String {
        let request = ChatRequest(
            model: run.request.model,
            messages: run.prompts.reportMessages(notes: notes),
            thinking: run.request.settings.thinkingLevel
        )
        var text = ""
        for try await delta in chat.streamChat(run.chatURL, request) {
            switch delta {
            case .thinking(let thinking):
                report(.thinking(thinking))
            case .text(let piece):
                text += piece
                report(.text(piece))
            case .searchRequested, .memoryRequested:
                // No tools are offered while a report is written, so there is nothing to carry out.
                break
            }
        }
        return text
    }
}
