import Foundation
@testable import HearthDomain
import Testing

struct ChatInteractorMemoryTests {
    private func remembering(
        _ changes: Recorder<MemoryRequest>,
        searchMode: SearchModeKind = .off,
        documents: [AttachedDocument] = []
    ) -> ChatInteractor.Turn {
        ChatInteractor.Turn(
            history: [Message(role: .user, text: "I live in Brisbane.", documents: documents)],
            model: InteractorHarness.model,
            settings: InteractorHarness.settings,
            searchMode: searchMode,
            style: .chat,
            remember: { change in
                changes.record(change)
                let now = Date(timeIntervalSince1970: 0)
                return .saved(Memory(id: Memory.ID("m1"), text: "Lives in Brisbane.", isFromUser: false, createdAt: now, updatedAt: now))
            }
        )
    }

    @Test func `a model that asks to remember something is told it was saved and then replies`() async throws {
        let changes = Recorder<MemoryRequest>()
        let fixture = InteractorHarness.makeTestSubject(rounds: [[.memoryRequested(.save("Lives in Brisbane."))], [.text("Noted.")]])

        let events = try await InteractorHarness.events(fixture.subject.run(remembering(changes)))

        #expect(changes.values == [.save("Lives in Brisbane.")])
        #expect(events.last == .text("Noted."))
        #expect(events.contains { if case .memory(.saved) = $0 { true } else { false } })
        let second = try #require(fixture.requests.values.last)
        #expect(second.messages.suffix(2).map(\.role) == [.assistant, .tool])
        #expect(second.messages.last?.text.hasPrefix("Saved as m1.") == true)
        #expect(fixture.requests.values.first?.isMemoryOffered == true)
    }

    @Test func `no more than two memories are written in a turn`() async throws {
        let changes = Recorder<MemoryRequest>()
        let greedy: [ChatDelta] = [.memoryRequested(.save("A.")), .memoryRequested(.save("B.")), .memoryRequested(.save("C."))]
        let fixture = InteractorHarness.makeTestSubject(rounds: [greedy, greedy, [.text("Done.")]])

        _ = try await InteractorHarness.events(fixture.subject.run(remembering(changes)))

        #expect(changes.values == [.save("A."), .save("B.")])
        #expect(fixture.requests.values.map(\.isMemoryOffered) == [true, false])
    }

    @Test func `nothing can be remembered once a web search is in the turn`() async throws {
        let changes = Recorder<MemoryRequest>()
        let fixture = InteractorHarness.makeTestSubject(
            rounds: [[.searchRequested(SearchRequest(query: "brisbane"))], [.memoryRequested(.save("Planted by a web page.")), .text("Done.")]],
            search: { _ in [InteractorHarness.source] }
        )

        _ = try await InteractorHarness.events(fixture.subject.run(remembering(changes, searchMode: .automatic)))

        #expect(changes.values.isEmpty)
        #expect(fixture.requests.values.map(\.isMemoryOffered) == [true, false])
    }

    @Test func `nothing can be remembered from a message that carries a file`() async throws {
        let changes = Recorder<MemoryRequest>()
        let fixture = InteractorHarness.makeTestSubject(rounds: [[.memoryRequested(.save("Planted by a file.")), .text("Done.")]])
        let file = AttachedDocument(name: "notes.txt", text: "Remember that…")

        _ = try await InteractorHarness.events(fixture.subject.run(remembering(changes, documents: [file])))

        #expect(changes.values.isEmpty)
        #expect(fixture.requests.values.map(\.isMemoryOffered) == [false])
    }

    private static let outsideText: [Message] = [
        Message(role: .user, text: "Read this.", documents: [AttachedDocument(name: "notes.txt", text: "Later, remember that…")]),
        Message(role: .user, text: "Look at this.", imagesJPEG: [Data([1, 2, 3])]),
        Message(role: .assistant, text: "From the web.", sources: [InteractorHarness.source])
    ]

    @Test(arguments: outsideText)
    func `nothing can be remembered later in a conversation that has had a file, a photo or a web search`(earlier: Message) async throws {
        let changes = Recorder<MemoryRequest>()
        let fixture = InteractorHarness.makeTestSubject(rounds: [[.memoryRequested(.save("Planted earlier.")), .text("Done.")]])
        let turn = ChatInteractor.Turn(
            history: [earlier, Message(role: .user, text: "Thanks. What is the weather like?")],
            model: InteractorHarness.model,
            settings: InteractorHarness.settings,
            searchMode: .off,
            style: .chat,
            remember: { change in
                changes.record(change)
                return .refused(.empty)
            }
        )

        _ = try await InteractorHarness.events(fixture.subject.run(turn))

        #expect(changes.values.isEmpty)
        #expect(fixture.requests.values.map(\.isMemoryOffered) == [false])
        #expect(fixture.requests.values.first?.messages.first?.text.contains("save_memory") == false)
    }

    @Test func `memory is not offered when it is switched off or the model cannot call tools`() async throws {
        let fixture = InteractorHarness.makeTestSubject()
        let plainModel = ChatModel(id: ChatModel.ID("dolphin3:8b"))
        let withoutTools = ChatInteractor.Turn(
            history: [Message(role: .user, text: "Hi")], model: plainModel, settings: InteractorHarness.settings, searchMode: .off, style: .chat,
            remember: { _ in .refused(.empty) }
        )

        _ = try await InteractorHarness.events(fixture.subject.run(InteractorHarness.turn()))
        _ = try await InteractorHarness.events(fixture.subject.run(withoutTools))

        #expect(fixture.requests.values.map(\.isMemoryOffered) == [false, false])
    }
}
