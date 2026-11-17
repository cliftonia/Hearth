import Foundation
import HearthData
@testable import HearthDomain
import Testing

/// A value shared between a test and the closures it hands out, safely across tasks.
final class Box<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: Value

    init(_ value: Value) {
        stored = value
    }

    var value: Value {
        get { lock.withLock { stored } }
        set { lock.withLock { stored = newValue } }
    }

    func update(_ change: (inout Value) -> Void) {
        lock.withLock { change(&stored) }
    }
}

/// A hub in memory with the real hub's rules: last writer wins by time then writer, tombstones are kept, every
/// change gets the next number, and changes come in pages.
final class FakeHub: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [String: SyncEnvelopeDTO] = [:]
    private var seq = 0
    var hubID = "hub-one"
    /// How many changes one page holds.
    var pageLimit = 200
    /// Thrown by every request while set, as a hub that is down or refuses the token.
    var failure: (any Error & Sendable)?
    /// Items the hub refuses as too large, by identifier.
    var tooLargeIDs: Set<String> = []
    /// Run just before a `PUT` is weighed, as another device writing at that moment.
    var beforePut: (@Sendable (SyncItemKey) -> Void)?
    private(set) var puts: [SyncItemKey] = []

    var provider: SyncDataProvider {
        SyncDataProvider(
            health: { _ in
                try self.check()
                return SyncHealthDTO(ok: true, seq: self.latestSeq, hubId: self.hubID, authRequired: false)
            },
            changes: { _, _, since in try self.changes(since: since) },
            put: { _, _, key, change in try self.put(key, change) }
        )
    }

    var latestSeq: Int { lock.withLock { seq } }

    func envelope(_ kind: SyncItemKind, _ id: String) -> SyncEnvelopeDTO? {
        lock.withLock { items["\(kind.rawValue)/\(id.lowercased())"] }
    }

    /// Every item the hub holds, deletions included.
    var all: [SyncEnvelopeDTO] {
        lock.withLock { Array(items.values) }
    }

    /// Stores a change as another device would have sent it, if it wins.
    @discardableResult
    func seed(_ key: SyncItemKey, at milliseconds: Int64, by writer: String = "other-device", deleted: Bool = false, body: JSONValue?) -> Bool {
        let change = SyncPutDTO(updatedAt: WireTime.date(milliseconds: milliseconds), updatedBy: writer, deleted: deleted, body: body)
        if case .accepted = store(key, change) {
            return true
        }
        return false
    }

    private func check() throws {
        if let failure {
            throw failure
        }
    }

    private func changes(since: Int) throws -> SyncChangesDTO {
        try check()
        return lock.withLock {
            let after = items.values.filter { $0.seq > since }.sorted { $0.seq < $1.seq }
            let page = Array(after.prefix(pageLimit))
            return SyncChangesDTO(hubId: hubID, items: page, next: page.last?.seq ?? since, hasMore: after.count > page.count)
        }
    }

    private func put(_ key: SyncItemKey, _ change: SyncPutDTO) throws -> SyncPutResultDTO {
        try check()
        lock.withLock { puts.append(key) }
        if tooLargeIDs.contains(key.id) {
            return .tooLarge
        }
        beforePut?(key)
        return store(key, change)
    }

    private func store(_ key: SyncItemKey, _ change: SyncPutDTO) -> SyncPutResultDTO {
        lock.withLock {
            let name = "\(key.kind.rawValue)/\(key.id)"
            let stamp = SyncStamp(date: change.updatedAt, writer: change.updatedBy)
            if let held = items[name], SyncStamp(date: held.updatedAt, writer: held.updatedBy) > stamp {
                return .conflict(held)
            }
            seq += 1
            let body: JSONValue = change.deleted ? .object([:]) : (change.body ?? .object([:]))
            let stored = SyncEnvelopeDTO(
                kind: key.kind.rawValue, id: key.id, updatedAt: change.updatedAt, updatedBy: change.updatedBy, deleted: change.deleted, body: body, seq: seq
            )
            items[name] = stored
            return .accepted(stored)
        }
    }
}

/// One device: its stores kept in memory, its sync journal, a clock that only moves when told, and the interactor.
@MainActor
final class SyncDevice {
    let conversationFiles = Box<[Conversation.ID: Conversation]>([:])
    let projectFiles = Box<[Project.ID: Project]>([:])
    let memoryFile = Box<[Memory]>([])
    let taskFiles = Box<[ScheduledTask.ID: ScheduledTask]>([:])
    let journalFile = Box<Data?>(nil)
    let token = Box<String?>(nil)
    /// The hub this device talks to; it can be swapped, as for a hub started afresh.
    let hub: Box<FakeHub>
    /// Milliseconds since 1970 by this device's clock.
    var now: Int64
    var busy: Set<Conversation.ID> = []
    private(set) var appliedRemotely: [Set<SyncItemKey>] = []
    private(set) var reported: [SyncLocalChangeKind] = []
    /// The chats each sync reported as new answers to scheduled tasks.
    private(set) var taskResults: [[Conversation.ID]] = []

    let conversations: ConversationStore
    let projects: ProjectStore
    let memories: MemoryStore
    let tasks: TaskStore
    let sync: SyncStore
    private(set) var interactor: SyncInteractor!

    init(hub: FakeHub, now: Int64 = 1_000_000) {
        self.now = now
        self.hub = Box(hub)
        let (conversationFiles, projectFiles, memoryFile, journalFile, token) = (conversationFiles, projectFiles, memoryFile, journalFile, token)
        let settings = Box<Data?>(try? JSONEncoder().encode(SyncSettings(hubAddress: "https://hub.example", isEnabled: true)))
        var clock: @MainActor () -> Date = { Date() }
        conversations = ConversationStore(provider: ConversationDataProvider(
            loadAll: { Array(conversationFiles.value.values) },
            save: { conversation in conversationFiles.update { $0[conversation.id] = conversation } },
            delete: { id in conversationFiles.update { $0[id] = nil } },
            deleteAll: { conversationFiles.value = [:] }
        ), clock: { clock() })
        projects = ProjectStore(provider: ProjectDataProvider(
            loadAll: { Array(projectFiles.value.values) },
            save: { project in projectFiles.update { $0[project.id] = project } },
            delete: { id in projectFiles.update { $0[id] = nil } },
            deleteAll: { projectFiles.value = [:] }
        ), clock: { clock() })
        memories = MemoryStore(provider: MemoryDataProvider(load: { memoryFile.value }, save: { memoryFile.value = $0 }), clock: { clock() })
        tasks = TaskStore(provider: Self.provider(for: taskFiles), clock: { clock() })
        sync = SyncStore(provider: SyncStoreProvider(
            loadSettings: { settings.value },
            saveSettings: { settings.value = $0 },
            loadJournal: { journalFile.value },
            saveJournal: { journalFile.value = $0 },
            readToken: { token.value },
            writeToken: { token.value = $0 }
        ), clock: { clock() })
        clock = { [unowned self] in self.tick() }
        let stores = SyncInteractor.Stores(conversations: conversations, projects: projects, memories: memories, tasks: tasks, sync: sync)
        interactor = SyncInteractor(
            stores: stores,
            provider: SyncDataProvider(
                health: { [hub = self.hub] in try await hub.value.provider.health($0) },
                changes: { [hub = self.hub] in try await hub.value.provider.changes($0, $1, $2) },
                put: { [hub = self.hub] in try await hub.value.provider.put($0, $1, $2, $3) }
            ),
            isBusy: { [unowned self] in self.busy.contains($0) },
            didApplyRemote: { [unowned self] in self.appliedRemotely.append($0) },
            didReceiveTaskResults: { [unowned self] in self.taskResults.append($0) }
        )
        let record: @MainActor (SyncLocalChangeKind) -> Void = { [unowned self] change in
            self.reported.append(change)
            self.sync.record(change)
        }
        conversations.onLocalChange = record
        projects.onLocalChange = record
        memories.onLocalChange = record
        tasks.onLocalChange = record
    }

    /// Tasks kept in memory, in the box given.
    private static func provider(for files: Box<[ScheduledTask.ID: ScheduledTask]>) -> TaskDataProvider {
        TaskDataProvider(
            loadAll: { Array(files.value.values) },
            save: { task in files.update { $0[task.id] = task } },
            delete: { id in files.update { $0[id] = nil } },
            deleteAll: { files.value = [:] }
        )
    }

    /// The clock's time, then a millisecond later for the next caller, so every stamp is distinct.
    private func tick() -> Date {
        now += 1
        return WireTime.date(milliseconds: now)
    }

    @discardableResult
    func syncNow() async throws -> Int {
        try await interactor.sync()
    }
}

/// Bodies as another client would write them, built from the app's own DTOs.
enum SyncSamples {
    static let created = WireTime.date(milliseconds: 900_000)

    static func conversation(_ id: Conversation.ID = Conversation.ID(UUID()), title: String, messages: [Message] = []) -> Conversation {
        Conversation(id: id, title: title, messages: messages, createdAt: created, updatedAt: created)
    }

    static func body(of conversation: Conversation) -> JSONValue {
        (try? SyncWire.json(from: ConversationBodyDTO(from: conversation))) ?? .null
    }

    static func body(of project: Project) -> JSONValue {
        (try? SyncWire.json(from: ProjectBodyDTO(from: project))) ?? .null
    }

    static func memoryBody(_ text: String) -> JSONValue {
        (try? SyncWire.json(from: MemoryBodyDTO(schema: 1, text: text, isFromUser: true, createdAt: created))) ?? .null
    }

    /// A body as it came from the hub, read back into a conversation.
    static func conversation(from envelope: SyncEnvelopeDTO?) throws -> Conversation {
        let envelope = try #require(envelope)
        let dto = try SyncWire.decode(ConversationBodyDTO.self, from: try #require(envelope.body))
        return try Conversation(from: dto, id: Conversation.ID(try #require(UUID(uuidString: envelope.id))), modifiedAt: envelope.updatedAt)
    }
}
