import Foundation
import HearthDomain
@testable import HearthUI
import Testing

/// How deep research is chosen in the chat, run, stopped, kept and asked for again.
@MainActor
struct ChatResearchTests {
    /// Counts calls, safely across tasks.
    final class Counter: @unchecked Sendable {
        private let lock = NSLock()
        private var count = 0

        var value: Int { lock.withLock { count } }

        func increment() {
            lock.withLock { count += 1 }
        }
    }

    /// The chat presenter with a scripted model, search and web behind its research.
    @MainActor
    final class Fixture {
        static let model = ChatModel(id: ChatModel.ID("gemma4:latest"), canThink: true, canUseTools: true)
        static let html = "<html><body><p>" + String(repeating: "Heat pumps move heat. ", count: 20) + "</p></body></html>"
        static let sources = (1...3).map { number in
            SearchSource(title: "Page \(number)", url: URL(string: "https://site\(number).example/page") ?? URL(filePath: "/"), snippet: "")
        }

        let settingsStore: SettingsStore
        let conversationStore = PresenterFixtures.conversationStore()
        /// How many times research was planned, and how many ordinary replies were streamed.
        let plans = Counter()
        let replies = Counter()
        /// What the web serves for a page. The default is a page worth reading.
        var page: @Sendable (URL) async throws -> String = { _ in Fixture.html }

        init(searchAddress: String = "https://search.example") {
            let settings = ServerSettings(
                ollamaAddress: "https://ollama.example",
                searchAddress: searchAddress,
                isFollowUpsEnabled: false,
                thinkingLevel: .low
            )
            settingsStore = PresenterFixtures.settingsStore(settings)
        }

        func makeTestSubject() -> ChatPresenter {
            let (plans, replies, page) = (plans, replies, page)
            let researchChat = ChatDataProvider(
                fetchModels: { _ in [] },
                streamChat: { _, _ in
                    AsyncThrowingStream { continuation in
                        // Cites the first and third pages, and one that does not exist.
                        continuation.yield(.text("Pumps move heat [1]. They work in the cold [3][8]."))
                        continuation.finish()
                    }
                },
                complete: { _, request in
                    let prompt = request.messages.last?.text ?? ""
                    if prompt.hasPrefix("Plan the web searches") {
                        plans.increment()
                        return #"{"queries": ["heat pumps"]}"#
                    }
                    return prompt.hasPrefix("You are taking notes") ? "- A fact." : #"{"queries": []}"#
                }
            )
            let ordinaryChat = ChatDataProvider(
                fetchModels: { _ in [] },
                streamChat: { _, _ in
                    replies.increment()
                    return AsyncThrowingStream { continuation in
                        continuation.yield(.text("An ordinary reply."))
                        continuation.finish()
                    }
                },
                complete: { _, _ in "" }
            )
            let search = SearchDataProvider(fetchPage: page) { _, _ in Fixture.sources }
            let subject = ChatPresenter(dependencies: ChatPresenter.Dependencies(
                chat: ChatInteractor(chat: ordinaryChat, search: SearchDataProvider { _, _ in [] }),
                speech: PresenterFixtures.speech,
                image: PresenterFixtures.image,
                research: ResearchInteractor(chat: researchChat, search: search),
                dictation: PresenterFixtures.dictation,
                notifications: NotificationsFixture(permission: .denied).provider,
                photoLibrary: PresenterFixtures.photoLibrary,
                settingsStore: settingsStore,
                modelStore: ModelStore(fetchModels: { _ in [Fixture.model] }),
                conversationStore: conversationStore,
                memoryStore: PresenterFixtures.memoryStore(),
                projectStore: PresenterFixtures.projectStore(),
                isLocked: { false },
                isOnScreen: { true },
                announce: { _ in },
                isVoiceOverRunning: { false }
            ))
            subject.viewModel.selectedModel = Self.model
            return subject
        }
    }

    /// Waits, for a few seconds at most, until something that happens on another task has happened.
    private func wait(until condition: () -> Bool) async {
        for _ in 0..<400 where !condition() {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    // MARK: Choosing

    @Test func `research is chosen as an effort of its own, and leaves the saved thinking level alone`() {
        let fixture = Fixture()
        let subject = fixture.makeTestSubject()

        #expect(subject.effortChoices == [.thinking(.off), .thinking(.low), .thinking(.medium), .thinking(.high), .research])
        #expect(subject.effortChoice == .thinking(.low))
        subject.selectEffortAction(.research)

        #expect(subject.effortChoice == .research)
        #expect(subject.isResearchChosen)
        #expect(subject.effortChipTitle == Strings.research)
        #expect(fixture.settingsStore.settings.thinkingLevel == .low)

        subject.selectEffortAction(.thinking(.high))

        #expect(subject.effortChoice == .thinking(.high))
        #expect(!subject.isResearchChosen)
        #expect(fixture.settingsStore.settings.thinkingLevel == .high)
    }

    @Test func `a model that cannot think is still offered research, beside one ordinary choice`() {
        let subject = Fixture().makeTestSubject()
        subject.viewModel.selectedModel = ChatModel(id: ChatModel.ID("plain:latest"))

        #expect(subject.effortChoices == [.thinking(.low), .research])
        #expect(subject.effortChipTitle.isEmpty)
        #expect(EffortChoiceKind.thinking(.low).title(canThink: false) == Strings.effortStandard)
        subject.selectEffortAction(.research)

        #expect(subject.effortChipTitle == Strings.research)
    }

    @Test func `without a search address research is listed but cannot be chosen`() {
        let subject = Fixture(searchAddress: "").makeTestSubject()

        #expect(subject.effortChoices.contains(.research))
        #expect(!subject.isEffortChoiceAvailable(.research))
        #expect(subject.isEffortChoiceAvailable(.thinking(.high)))
        subject.selectEffortAction(.research)

        #expect(subject.effortChoice == .thinking(.low))
    }

    @Test func `the choice stays with its chat: a new chat, or another chat, starts without it`() async {
        let fixture = Fixture()
        let subject = fixture.makeTestSubject()
        let other = Conversation(title: "Other", messages: [Message(role: .user, text: "Hello")])
        try? await fixture.conversationStore.save(other)

        subject.selectEffortAction(.research)
        await subject.newChatAction()
        #expect(subject.effortChoice == .thinking(.low))

        subject.selectEffortAction(.research)
        await subject.selectConversationAction(other.id)
        #expect(subject.effortChoice == .thinking(.low))
    }

    @Test func `a message asks for a picture or for research, never both`() {
        let subject = Fixture().makeTestSubject()

        subject.selectEffortAction(.research)
        subject.togglePictureModeAction()

        #expect(subject.viewModel.isPictureMode)
        #expect(!subject.isResearchChosen)
        #expect(!subject.viewModel.isResearchMode)
    }

    // MARK: Running

    @Test func `a researched question is answered with a report that is kept with its sources and its mark`() async throws {
        let fixture = Fixture()
        let subject = fixture.makeTestSubject()
        subject.selectEffortAction(.research)
        subject.viewModel.draft = "How do heat pumps work?"

        await subject.sendAction()

        let conversation = subject.viewModel.conversation
        let report = try #require(conversation.messages.last)
        #expect(conversation.messages.count == 2)
        #expect(report.isResearch)
        // The citation with nothing behind it is gone, and the two sources cited are numbered one and two.
        #expect(report.text == "Pumps move heat [1]. They work in the cold [2].")
        #expect(report.sources == [Fixture.sources[0], Fixture.sources[2]])
        #expect(fixture.conversationStore.conversation(for: conversation.id)?.messages.last == report)
        #expect(!subject.viewModel.isStreaming)
        #expect(subject.viewModel.researchStatus == nil)
        #expect(subject.viewModel.error == nil)
        #expect(fixture.replies.value == 0)
        // Research is still chosen, so the next question in this chat would be researched too.
        #expect(subject.isResearchChosen)
    }

    @Test func `with research switched off again, the next question in the chat is an ordinary one`() async throws {
        let fixture = Fixture()
        let subject = fixture.makeTestSubject()
        subject.selectEffortAction(.research)
        subject.viewModel.draft = "How do heat pumps work?"
        await subject.sendAction()

        subject.selectEffortAction(.thinking(.low))
        subject.viewModel.draft = "Thanks. And in summer?"
        await subject.sendAction()

        let reply = try #require(subject.viewModel.conversation.messages.last)
        #expect(reply.text == "An ordinary reply.")
        #expect(!reply.isResearch)
        #expect(fixture.plans.value == 1)
        #expect(fixture.replies.value == 1)
    }

    @Test func `trying a report again researches again, even with research no longer chosen`() async throws {
        let fixture = Fixture()
        let subject = fixture.makeTestSubject()
        subject.selectEffortAction(.research)
        subject.viewModel.draft = "How do heat pumps work?"
        await subject.sendAction()
        subject.selectEffortAction(.thinking(.low))

        await subject.regenerateAction()

        let report = try #require(subject.viewModel.conversation.messages.last)
        #expect(fixture.plans.value == 2)
        #expect(fixture.replies.value == 0)
        #expect(report.isResearch)
        #expect(report.versionCount == 2)
        #expect(report.sources == [Fixture.sources[0], Fixture.sources[2]])
    }

    @Test func `when no page can be read it says so, writes nothing, and retrying researches again`() async {
        let fixture = Fixture()
        fixture.page = { _ in throw URLError(.badServerResponse) }
        let subject = fixture.makeTestSubject()
        await subject.refreshModelsAction()
        subject.selectEffortAction(.research)
        subject.viewModel.draft = "How do heat pumps work?"

        await subject.sendAction()

        let expected = ErrorViewConfiguration(title: Strings.research, message: Strings.errorResearchNothingReadable)
        #expect(subject.viewModel.error == expected)
        #expect(subject.viewModel.error?.retryActionLabel == Strings.retry)
        #expect(subject.viewModel.conversation.messages.map(\.role) == [.user])

        await subject.retryAction()

        #expect(fixture.plans.value == 2)
        #expect(fixture.replies.value == 0)
    }

    @Test func `stopping ends the run at once and leaves no empty report behind`() async {
        let fixture = Fixture()
        // Pages that would take a minute to arrive, unless the run is stopped.
        fixture.page = { _ in
            try await Task.sleep(for: .seconds(60))
            return Fixture.html
        }
        let subject = fixture.makeTestSubject()
        subject.selectEffortAction(.research)
        subject.viewModel.draft = "How do heat pumps work?"
        let clock = ContinuousClock()
        let startedAt = clock.now

        let sending = Task { await subject.sendAction() }
        await wait { subject.viewModel.researchStatus == Strings.researchReading(number: 1, total: 3) }
        #expect(subject.viewModel.isStreaming)
        await subject.stopAction()
        await sending.value

        #expect(clock.now - startedAt < .seconds(5))
        #expect(!subject.viewModel.isStreaming)
        #expect(subject.viewModel.researchStatus == nil)
        #expect(subject.viewModel.error == nil)
        #expect(subject.viewModel.conversation.messages.map(\.role) == [.user])
    }

    @Test(arguments: [
        (ResearchStepKind.planning, "Planning"),
        (.searching(number: 3, total: 5), "Searching 3 of 5"),
        (.reading(number: 4, total: 11), "Reading 4 of 11"),
        (.takingNotes(number: 2, total: 9), "Taking notes 2 of 9"),
        (.checking, "Checking for gaps"),
        (.writing, "Writing")
    ])
    func `each step is shown in plain words`(step: ResearchStepKind, expected: String) {
        #expect(ChatPresenter.status(for: step) == expected)
    }

    @Test func `a report's sources are listed by the numbers it cites them by`() {
        let list = ResearchSourceViewConfiguration.list(from: [
            SearchSource(title: "  Heat pumps\n explained ", url: URL(string: "https://www.site1.example/a") ?? URL(filePath: "/"), snippet: ""),
            SearchSource(title: "", url: URL(string: "https://site2.example/b") ?? URL(filePath: "/"), snippet: "")
        ])

        #expect(list.map(\.number) == [1, 2])
        #expect(list.map(\.title) == ["Heat pumps explained", "site2.example"])
        #expect(list.map(\.host) == ["site1.example", "site2.example"])
        #expect(list.map(\.isLast) == [false, true])
    }
}
