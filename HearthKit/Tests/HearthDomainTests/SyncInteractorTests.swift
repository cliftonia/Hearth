import Foundation
import HearthData
@testable import HearthDomain
import Testing

/// One sync from end to end, between devices kept in memory and a hub with the real hub's rules.
@MainActor
struct SyncInteractorTests {
    @Test func `a first sync on a device that has data merges both ways`() async throws {
        let hub = FakeHub()
        let theirs = SyncSamples.conversation(title: "From the phone")
        hub.seed(.conversation(theirs.id), at: 500_000, body: SyncSamples.body(of: theirs))
        let device = SyncDevice(hub: hub)
        try await device.conversations.save(SyncSamples.conversation(title: "From the tablet"))

        try await device.syncNow()

        #expect(Set(device.conversations.conversations.map(\.title)) == ["From the phone", "From the tablet"])
        #expect(hub.all.count == 2)
        // Nothing more to send once both sides hold the same.
        let putsBefore = hub.puts.count
        try await device.syncNow()
        #expect(hub.puts.count == putsBefore)
    }

    @Test func `a chat made on one device reaches the other, and a change made there comes back`() async throws {
        let hub = FakeHub()
        let tablet = SyncDevice(hub: hub, now: 1_000_000)
        let phone = SyncDevice(hub: hub, now: 2_000_000)
        let chat = SyncSamples.conversation(title: "Tides", messages: [Message(role: .user, text: "When?")])
        try await tablet.conversations.save(chat)
        try await tablet.syncNow()

        try await phone.syncNow()
        #expect(phone.conversations.conversation(for: chat.id)?.messages.map(\.text) == ["When?"])

        try await phone.conversations.rename(chat.id, to: "Tide times")
        try await phone.conversations.setPinned(true, for: chat.id)
        try await phone.syncNow()
        try await tablet.syncNow()

        let arrived = try #require(tablet.conversations.conversation(for: chat.id))
        #expect((arrived.title, arrived.isPinned) == ("Tide times", true))
        #expect(tablet.appliedRemotely.contains { $0.contains(.conversation(chat.id)) })
    }

    @Test func `the newer copy wins whichever side holds it`() async throws {
        let hub = FakeHub()
        let device = SyncDevice(hub: hub, now: 1_000_000)
        let older = SyncSamples.conversation(title: "Local")
        let newer = SyncSamples.conversation(title: "Remote newer")
        try await device.conversations.save(older)
        try await device.conversations.save(newer.updating(title: "Local older"))
        // The hub's copy of `older` is from before the device changed it; its copy of `newer` from after.
        hub.seed(.conversation(older.id), at: 10, body: SyncSamples.body(of: older.updating(title: "Remote older")))
        hub.seed(.conversation(newer.id), at: 5_000_000, body: SyncSamples.body(of: newer))

        try await device.syncNow()

        #expect(device.conversations.conversation(for: older.id)?.title == "Local")
        #expect(device.conversations.conversation(for: newer.id)?.title == "Remote newer")
        #expect(try SyncSamples.conversation(from: hub.envelope(.conversation, older.id.rawValue.uuidString)).title == "Local")
    }

    @Test func `a deletion here goes to the hub as a tombstone, and one from the hub deletes here`() async throws {
        let hub = FakeHub()
        let device = SyncDevice(hub: hub)
        let mine = SyncSamples.conversation(title: "Mine")
        let theirs = SyncSamples.conversation(title: "Theirs")
        try await device.conversations.save(mine)
        try await device.conversations.save(theirs)
        try await device.syncNow()

        try await device.conversations.delete(mine.id)
        hub.seed(.conversation(theirs.id), at: 9_000_000, deleted: true, body: nil)
        try await device.syncNow()

        #expect(device.conversations.conversations.isEmpty)
        #expect(hub.envelope(.conversation, mine.id.rawValue.uuidString)?.deleted == true)
        #expect(device.sync.journal.tombstones.isEmpty)
    }

    @Test func `a project deleted elsewhere keeps its chats here, without sending them`() async throws {
        let hub = FakeHub()
        let device = SyncDevice(hub: hub)
        let project = Project(name: "Garden")
        try await device.projects.save(project)
        try await device.conversations.save(SyncSamples.conversation(title: "Beds").updating(project: .project(project.id)))
        try await device.syncNow()
        let putsBefore = hub.puts.count

        hub.seed(.project(project.id), at: 9_000_000, deleted: true, body: nil)
        try await device.syncNow()

        #expect(device.projects.projects.isEmpty)
        #expect(device.conversations.conversations.map(\.projectID) == [nil])
        #expect(hub.puts.count == putsBefore)
    }

    @Test func `private chats never reach the hub, not even as a deletion`() async throws {
        let hub = FakeHub()
        let device = SyncDevice(hub: hub)
        let secret = Conversation(title: "Secret", messages: [Message(role: .user, text: "Hush")], isPrivate: true)
        try await device.conversations.save(secret)
        try await device.conversations.rename(secret.id, to: "Still secret")
        try await device.syncNow()
        try await device.conversations.delete(secret.id)
        try await device.syncNow()

        #expect(hub.all.isEmpty)
        #expect(device.reported.isEmpty)
        #expect(device.sync.journal.tombstones.isEmpty)
    }

    @Test func `a chat whose reply is streaming is neither replaced nor sent until it is finished`() async throws {
        let hub = FakeHub()
        let device = SyncDevice(hub: hub)
        let chat = SyncSamples.conversation(title: "Open")
        try await device.conversations.save(chat)
        try await device.syncNow()
        hub.seed(.conversation(chat.id), at: 9_000_000, body: SyncSamples.body(of: chat.updating(title: "Renamed elsewhere")))
        device.busy = [chat.id]

        try await device.syncNow()
        #expect(device.conversations.conversation(for: chat.id)?.title == "Open")
        #expect(device.sync.journal.cursor < hub.latestSeq)

        device.busy = []
        try await device.syncNow()
        #expect(device.conversations.conversation(for: chat.id)?.title == "Renamed elsewhere")
        #expect(device.sync.journal.cursor == hub.latestSeq)
    }

    @Test func `a 409 means the hub's newer copy is taken`() async throws {
        let hub = FakeHub()
        let device = SyncDevice(hub: hub)
        let chat = SyncSamples.conversation(title: "Mine")
        try await device.conversations.save(chat)
        // Another device writes a later copy between this device's pull and its push.
        hub.beforePut = { key in
            hub.beforePut = nil
            hub.seed(key, at: 9_000_000, body: SyncSamples.body(of: chat.updating(title: "Theirs, later")))
        }

        try await device.syncNow()

        #expect(device.conversations.conversation(for: chat.id)?.title == "Theirs, later")
        #expect(device.sync.journal.seen[.conversation(chat.id)]?.milliseconds == 9_000_000)
    }

    @Test func `changes come in pages until there are no more`() async throws {
        let hub = FakeHub()
        hub.pageLimit = 2
        for number in 1...5 {
            let chat = SyncSamples.conversation(title: "Chat \(number)")
            hub.seed(.conversation(chat.id), at: Int64(number), body: SyncSamples.body(of: chat))
        }
        let device = SyncDevice(hub: hub)

        try await device.syncNow()

        #expect(device.conversations.conversations.count == 5)
        #expect(device.sync.journal.cursor == 5)
    }

    @Test func `a hub started afresh is synced with from the start`() async throws {
        let hub = FakeHub()
        let device = SyncDevice(hub: hub)
        try await device.conversations.save(SyncSamples.conversation(title: "Kept"))
        try await device.syncNow()

        let fresh = FakeHub()
        fresh.hubID = "hub-two"
        device.hub.value = fresh
        try await device.syncNow()

        #expect(device.sync.journal.hubID == "hub-two")
        #expect(fresh.all.count == 1)
    }

    @Test func `projects and memories sync, a memory getting a handle of this device's own`() async throws {
        let hub = FakeHub()
        let device = SyncDevice(hub: hub)
        await device.memories.apply(.save("Likes tea"), isFromUser: true)
        let theirs = UUID()
        hub.seed(.memory(theirs), at: 5, body: SyncSamples.memoryBody("Lives in Brisbane"))
        let project = Project(name: "Garden", instructions: "Subtropical.")
        hub.seed(.project(project.id), at: 6, body: SyncSamples.body(of: project))

        try await device.syncNow()

        #expect(device.memories.memories.map(\.id.rawValue) == ["m1", "m2"])
        #expect(device.memories.memories.last?.syncID == theirs)
        #expect(device.projects.project(for: project.id)?.instructions == "Subtropical.")
        #expect(hub.envelope(.memory, device.memories.memories[0].syncID.uuidString) != nil)
    }

    @Test func `fields from a newer client are given back when the item is uploaded again`() async throws {
        let hub = FakeHub()
        let chat = SyncSamples.conversation(title: "Briefing", messages: [Message(role: .user, text: "News?")])
        guard case .object(var body) = SyncSamples.body(of: chat), case .array(var messages) = body["messages"],
              case .object(var message) = messages[0] else {
            Issue.record("The sample body is not an object")
            return
        }
        message["mood"] = .string("curious")
        messages[0] = .object(message)
        body["messages"] = .array(messages)
        body["taskId"] = .string("T1")
        body["schema"] = .integer(2)
        hub.seed(.conversation(chat.id), at: 5, body: .object(body))
        let device = SyncDevice(hub: hub)
        try await device.syncNow()

        try await device.conversations.rename(chat.id, to: "Morning briefing")
        try await device.syncNow()

        let uploaded = try #require(hub.envelope(.conversation, chat.id.rawValue.uuidString)?.body?.objectValue)
        #expect(uploaded["title"] == .string("Morning briefing"))
        #expect(uploaded["taskId"] == .string("T1"))
        #expect(uploaded["schema"] == .integer(2))
        #expect(uploaded["messages"]?.arrayValue?.first?.objectValue?["mood"] == .string("curious"))
    }

    @Test func `an item too large for the hub stays here and is counted, and the rest sync`() async throws {
        let hub = FakeHub()
        let device = SyncDevice(hub: hub)
        let large = SyncSamples.conversation(title: "Pictures")
        try await device.conversations.save(large)
        try await device.conversations.save(SyncSamples.conversation(title: "Words"))
        hub.tooLargeIDs = [large.id.rawValue.uuidString.lowercased()]

        #expect(try await device.syncNow() == 1)
        #expect(hub.all.count == 1)
    }

    @Test func `a hub that wants a token, or is down, says so plainly`() async throws {
        let hub = FakeHub()
        let device = SyncDevice(hub: hub)
        hub.failure = HTTPError.status(code: 401, body: "")
        await #expect(throws: SyncError(.tokenNeeded)) { try await device.syncNow() }
        try device.sync.setToken("throwaway")
        await #expect(throws: SyncError(.tokenRefused)) { try await device.syncNow() }
        hub.failure = URLError(.cannotConnectToHost)
        await #expect(throws: SyncError(.unreachable)) { try await device.syncNow() }
        hub.failure = nil
        try await device.syncNow()
        #expect(device.sync.journal.hubID == "hub-one")
    }
}
