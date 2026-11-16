import Foundation
import HearthData
@testable import HearthDomain
import Testing

/// Scheduled tasks kept in step through the hub like any other item, with the hub itself writing back each run.
@MainActor
struct TaskSyncTests {
    private static let brisbane = "Australia/Brisbane"

    private func task(_ title: String = "Morning briefing") -> ScheduledTask {
        ScheduledTask(
            title: title,
            prompt: "The three biggest stories?",
            modelID: ChatModel.ID("gpt-oss:120b-cloud"),
            schedule: .daily(TaskTimeOfDay(hour: 7, minute: 30)!, timeZone: Self.brisbane),
            usesWebSearch: true,
            createdAt: SyncSamples.created,
            updatedAt: SyncSamples.created
        )
    }

    /// The task's body as the hub's runner leaves it after a run: the same body, with the run written in.
    private func bodyAfterRun(_ envelope: SyncEnvelopeDTO?, at seconds: Double, failed: Bool) throws -> JSONValue {
        var body = try #require(envelope?.body?.objectValue)
        body["lastRunAt"] = .double(seconds)
        body["lastRunFailed"] = .bool(failed)
        return .object(body)
    }

    @Test func `a task made on one device reaches another, and so does switching it off`() async throws {
        let hub = FakeHub()
        let phone = SyncDevice(hub: hub, now: 1_000_000)
        let tablet = SyncDevice(hub: hub, now: 2_000_000)
        let briefing = task()
        try await phone.tasks.save(briefing)
        #expect(phone.reported == [.changed(.task(briefing.id))])
        try await phone.syncNow()

        try await tablet.syncNow()
        let arrived = try #require(tablet.tasks.task(for: briefing.id))
        #expect(arrived.title == "Morning briefing")
        #expect(arrived.schedule == briefing.schedule)
        #expect(arrived.usesWebSearch)

        try await tablet.tasks.save(arrived.updating(isEnabled: false))
        try await tablet.syncNow()
        try await phone.syncNow()
        #expect(phone.tasks.task(for: briefing.id)?.isEnabled == false)
        let uploaded = try #require(hub.envelope(.task, briefing.id.rawValue.uuidString)?.body?.objectValue)
        #expect(uploaded["isEnabled"] == .bool(false))
        #expect(uploaded["schedule"]?.objectValue?["timeZone"] == .string(Self.brisbane))
    }

    @Test func `when the hub runs a task its last run arrives, and a later edit here keeps it`() async throws {
        let hub = FakeHub()
        let device = SyncDevice(hub: hub, now: 1_000_000)
        let briefing = task()
        try await device.tasks.save(briefing)
        try await device.syncNow()
        let key = SyncItemKey.task(briefing.id)

        hub.seed(key, at: 3_000_000, by: "hub", body: try bodyAfterRun(hub.envelope(.task, key.id), at: 1_794_864_605, failed: false))
        try await device.syncNow()

        let ran = try #require(device.tasks.task(for: briefing.id))
        #expect(ran.lastRunAt == Date(timeIntervalSince1970: 1_794_864_605))
        #expect(!ran.lastRunFailed)
        #expect(device.appliedRemotely.contains { $0.contains(key) })

        device.now = 4_000_000
        try await device.tasks.save(ran.updating(title: "Briefing"))
        try await device.syncNow()
        let uploaded = try SyncWire.decode(TaskBodyDTO.self, from: try #require(hub.envelope(.task, key.id)?.body))
        #expect(uploaded.title == "Briefing")
        #expect(uploaded.lastRunAt == 1_794_864_605)
    }

    @Test func `the hub's run wins over an edit here made before it`() async throws {
        let hub = FakeHub()
        let device = SyncDevice(hub: hub, now: 1_000_000)
        let briefing = task()
        try await device.tasks.save(briefing)
        try await device.syncNow()
        let key = SyncItemKey.task(briefing.id)
        // The device changes the task at 1,000,00x, the hub runs it later, at 3,000,000, before the device syncs.
        try await device.tasks.save(briefing.updating(prompt: "Five stories?"))
        hub.seed(key, at: 3_000_000, by: "hub", body: try bodyAfterRun(hub.envelope(.task, key.id), at: 1_794_864_605, failed: true))

        try await device.syncNow()

        let held = try #require(device.tasks.task(for: briefing.id))
        #expect(held.lastRunFailed)
        #expect(held.prompt == "The three biggest stories?")
    }

    @Test func `a task deleted here is deleted on the hub, and one deleted elsewhere goes from here`() async throws {
        let hub = FakeHub()
        let phone = SyncDevice(hub: hub, now: 1_000_000)
        let tablet = SyncDevice(hub: hub, now: 2_000_000)
        let first = task("First")
        let second = task("Second")
        try await phone.tasks.save(first)
        try await phone.tasks.save(second)
        try await phone.syncNow()
        try await tablet.syncNow()

        try await phone.tasks.delete(first.id)
        try await phone.syncNow()
        try await tablet.syncNow()

        #expect(hub.envelope(.task, first.id.rawValue.uuidString)?.deleted == true)
        #expect(tablet.tasks.tasks.map(\.title) == ["Second"])
        #expect(phone.sync.journal.tombstones.isEmpty)
    }

    @Test func `fields a newer app wrote into a task are given back`() async throws {
        let hub = FakeHub()
        let briefing = task()
        var body = try #require(try SyncWire.json(from: TaskBodyDTO(from: briefing)).objectValue)
        body["laterField"] = .object(["kept": .bool(true)])
        hub.seed(.task(briefing.id), at: 5, body: .object(body))
        let device = SyncDevice(hub: hub)
        try await device.syncNow()

        let held = try #require(device.tasks.task(for: briefing.id))
        try await device.tasks.save(held.updating(isEnabled: false))
        try await device.syncNow()

        let uploaded = try #require(hub.envelope(.task, briefing.id.rawValue.uuidString)?.body?.objectValue)
        #expect(uploaded["laterField"] == .object(["kept": .bool(true)]))
        #expect(uploaded["isEnabled"] == .bool(false))
    }

    @Test func `a new answer the hub files is reported once, but not while catching up from the start`() async throws {
        let hub = FakeHub()
        let taskID = ScheduledTask.ID(UUID())
        let old = SyncSamples.conversation(title: "Yesterday's briefing", messages: [Message(role: .assistant, text: "Old news")])
        hub.seed(.conversation(old.id), at: 500_000, by: "hub", body: filed(old, by: taskID))
        let device = SyncDevice(hub: hub)
        try await device.syncNow()
        #expect(device.taskResults.isEmpty)
        #expect(device.conversations.conversation(for: old.id)?.taskID == taskID)

        let new = SyncSamples.conversation(title: "Today's briefing", messages: [Message(role: .assistant, text: "News")])
        let ordinary = SyncSamples.conversation(title: "From the tablet")
        hub.seed(.conversation(new.id), at: 600_000, by: "hub", body: filed(new, by: taskID))
        hub.seed(.conversation(ordinary.id), at: 600_001, body: SyncSamples.body(of: ordinary))
        try await device.syncNow()
        #expect(device.taskResults == [[new.id]])

        // The same chat changed again is not new.
        hub.seed(.conversation(new.id), at: 700_000, by: "hub", body: filed(new.updating(title: "Renamed"), by: taskID))
        try await device.syncNow()
        #expect(device.taskResults == [[new.id]])
    }

    private func filed(_ conversation: Conversation, by taskID: ScheduledTask.ID) -> JSONValue {
        var body = SyncSamples.body(of: conversation).objectValue ?? [:]
        body["taskId"] = .string(taskID.rawValue.uuidString.lowercased())
        return .object(body)
    }
}
