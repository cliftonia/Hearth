import Foundation
@testable import HearthDomain
import Testing

/// How conversations are loaded, ordered, pinned and renamed, and how older saved ones are still read.
@MainActor
struct ConversationStoreTests {
    /// The store under test, with a record of what it wrote to disk.
    struct Fixture {
        let subject: ConversationStore
        let saved: Recorder<Conversation>
    }

    /// What a disk that cannot be written to throws.
    private struct DiskFull: Error {}

    /// A store whose disk already holds the given conversations.
    ///
    /// - Parameter failsWrites: Whether every save and delete fails, as on a full disk.
    private func makeTestSubject(stored: [Conversation] = [], failsWrites: Bool = false) -> Fixture {
        let saved = Recorder<Conversation>()
        let provider = ConversationDataProvider(
            loadAll: { stored },
            save: {
                if failsWrites { throw DiskFull() }
                saved.record($0)
            },
            delete: { _ in
                if failsWrites { throw DiskFull() }
            }
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

    @Test func `a failed save leaves the list as it is on disk`() async throws {
        let fixture = makeTestSubject(stored: [older, newer], failsWrites: true)
        try await fixture.subject.load()

        await #expect(throws: DiskFull.self) {
            try await fixture.subject.save(older.updating(title: "Changed"))
        }
        await #expect(throws: DiskFull.self) {
            try await fixture.subject.save(Conversation(title: "Brand new"))
        }

        #expect(fixture.subject.conversations.map(\.title) == ["Newer", "Older"])
    }

    @Test func `a failed pin, rename or delete is undone`() async throws {
        let fixture = makeTestSubject(stored: [older, newer], failsWrites: true)
        try await fixture.subject.load()

        await #expect(throws: DiskFull.self) { try await fixture.subject.setPinned(true, for: older.id) }
        await #expect(throws: DiskFull.self) { try await fixture.subject.rename(older.id, to: "Renamed") }
        await #expect(throws: DiskFull.self) { try await fixture.subject.delete(newer.id) }

        #expect(fixture.subject.conversations.map(\.title) == ["Newer", "Older"])
        #expect(fixture.subject.conversations.map(\.isPinned) == [false, false])
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

    @Test func `asking again keeps the earlier reply as a version that can be shown again`() {
        let first = Message(role: .assistant, text: "One", thinking: "Hm")

        let second = first.startingNewVersion().updating(text: "Two")
        let third = second.startingNewVersion().updating(text: "Three")

        #expect(third.versionCount == 3)
        #expect(third.versionIndex == 2)
        #expect(third.allVersions.map(\.text) == ["One", "Two", "Three"])
        let back = third.showingVersion(0)
        #expect(back.text == "One")
        #expect(back.thinking == "Hm")
        #expect(back.id == third.id)
        #expect(back.allVersions.map(\.text) == ["One", "Two", "Three"])
        #expect(back.showingVersion(7) == back)
    }

    @Test func `an attempt that came to nothing gives way to the reply before it`() throws {
        let first = Message(role: .assistant, text: "One")
        let empty = first.startingNewVersion()

        let restored = try #require(empty.droppingShownVersion())

        #expect(restored.text == "One")
        #expect(restored.versionCount == 1)
        #expect(first.droppingShownVersion() == nil)
    }

    @Test func `the versions of a reply survive a round trip through JSON`() throws {
        let reply = Message(role: .assistant, text: "One").startingNewVersion().updating(text: "Two")

        let decoded = try JSONDecoder().decode(Message.self, from: JSONEncoder().encode(reply))

        #expect(decoded == reply)
        #expect(decoded.allVersions.map(\.text) == ["One", "Two"])
    }
}
