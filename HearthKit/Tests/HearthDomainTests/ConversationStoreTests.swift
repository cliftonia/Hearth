import Foundation
@testable import HearthDomain
import Testing

@MainActor
struct ConversationStoreTests {
    struct Fixture {
        let subject: ConversationStore
        let saved: Recorder<Conversation>
    }

    private func makeTestSubject(stored: [Conversation] = []) -> Fixture {
        let saved = Recorder<Conversation>()
        let provider = ConversationDataProvider(
            loadAll: { stored },
            save: { saved.record($0) },
            delete: { _ in }
        )
        return Fixture(subject: ConversationStore(provider: provider), saved: saved)
    }

    private let older = Conversation(title: "Older", updatedAt: Date(timeIntervalSince1970: 100))
    private let newer = Conversation(title: "Newer", updatedAt: Date(timeIntervalSince1970: 200))

    @Test func `conversations load newest first`() async throws {
        let fixture = makeTestSubject(stored: [older, newer])

        try await fixture.subject.load()

        #expect(fixture.subject.conversations.map(\.title) == ["Newer", "Older"])
    }

    @Test func `pinning is written to disk and leaves the order alone`() async throws {
        let fixture = makeTestSubject(stored: [older, newer])
        try await fixture.subject.load()

        try await fixture.subject.setPinned(true, for: older.id)

        #expect(fixture.subject.conversations.map(\.title) == ["Newer", "Older"])
        #expect(fixture.subject.conversation(for: older.id)?.isPinned == true)
        #expect(fixture.saved.values.map(\.isPinned) == [true])
        #expect(fixture.saved.values.first?.updatedAt == older.updatedAt)
    }

    @Test func `saving a copy made before the pin does not undo it`() async throws {
        let fixture = makeTestSubject(stored: [older])
        try await fixture.subject.load()
        try await fixture.subject.setPinned(true, for: older.id)

        try await fixture.subject.save(older.updating(title: "Renamed"))

        #expect(fixture.subject.conversation(for: older.id)?.isPinned == true)
        #expect(fixture.subject.conversation(for: older.id)?.title == "Renamed")
        #expect(fixture.saved.values.last?.isPinned == true)
    }

    @Test func `renaming is written to disk and leaves the order alone`() async throws {
        let fixture = makeTestSubject(stored: [older, newer])
        try await fixture.subject.load()

        try await fixture.subject.rename(older.id, to: "Renamed")

        #expect(fixture.subject.conversations.map(\.title) == ["Newer", "Renamed"])
        #expect(fixture.saved.values.map(\.title) == ["Renamed"])
    }

    @Test func `a message saved before attachments existed still loads`() throws {
        let json = #"{"id":"\#(UUID().uuidString)","role":"user","text":"Hello","createdAt":0}"#

        let message = try JSONDecoder().decode(Message.self, from: Data(json.utf8))

        #expect(message.text == "Hello")
        #expect(message.documents.isEmpty)
        #expect(message.imagesJPEG.isEmpty)
    }

    @Test func `a conversation saved before pinning existed is read as not pinned`() throws {
        let id = UUID()
        let json = #"{"id":"\#(id.uuidString)","title":"Legacy","messages":[],"createdAt":0,"updatedAt":0}"#

        let conversation = try JSONDecoder().decode(Conversation.self, from: Data(json.utf8))

        #expect(conversation.title == "Legacy")
        #expect(conversation.isPinned == false)
        #expect(conversation.isPrivate == false)
    }

    @Test func `the pin and the private mark survive a round trip through JSON and other updates`() throws {
        let pinned = Conversation(title: "Kept", isPinned: true, isPrivate: true)
        #expect(pinned.updating(title: "Renamed").isPrivate)

        let decoded = try JSONDecoder().decode(Conversation.self, from: JSONEncoder().encode(pinned))

        #expect(decoded == pinned)
    }
}
