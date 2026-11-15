import Foundation
import Observation

/// What is remembered about the user, shared by the chat and the settings.
@MainActor
@Observable
public final class MemoryStore {
    public private(set) var memories: [Memory] = []
    /// Told of every change made on this device, for sync. Not told of erasing everything.
    @ObservationIgnored public var onLocalChange: (@MainActor (SyncLocalChangeKind) -> Void)?

    private let provider: MemoryDataProvider
    private let ledger = MemoryLedger()
    private let clock: @MainActor () -> Date

    /// - Parameter clock: The time changes are stamped with.
    public init(provider: MemoryDataProvider, clock: @escaping @MainActor () -> Date = { Date() }) {
        self.provider = provider
        self.clock = clock
    }

    public func load() async throws {
        memories = try await provider.load()
    }

    /// Applies a change and writes it to disk. A change that could not be written is undone and reported as refused.
    @discardableResult
    public func apply(_ request: MemoryRequest, isFromUser: Bool) async -> MemoryOutcome {
        let before = memories
        let result = ledger.applying(request, to: memories, isFromUser: isFromUser, now: clock())
        guard result.memories != before else {
            return result.outcome
        }
        let after = stamped(result.memories, before: before)
        memories = after
        do {
            try await provider.save(after)
        } catch {
            memories = before
            return .refused(.notStored)
        }
        report(from: before, to: after)
        return result.outcome
    }

    /// Forgets everything, as the user asks in the settings; each memory's deletion reaches the other devices.
    /// If that cannot be written, the memories are put back and the error is thrown.
    public func clear() async throws {
        let before = memories
        try await eraseAll()
        report(from: before, to: [])
    }

    /// Forgets everything on this device only, as when the user erases everything; sync is not told.
    /// If that cannot be written, the memories are put back and the error is thrown.
    public func eraseAll() async throws {
        let before = memories
        memories = []
        do {
            try await provider.save([])
        } catch {
            memories = before
            throw error
        }
    }

    // MARK: From another device

    /// Keeps a memory from another device, written as it came, stamp included. A memory already held keeps its
    /// handle; a new one is given the next free handle on this device.
    public func applyRemote(_ memory: Memory) async throws {
        let existing = memories.first { $0.syncID == memory.syncID }
        let handle = existing?.id ?? ledger.nextID(after: memories)
        let kept = Memory(
            id: handle, text: memory.text, isFromUser: memory.isFromUser, createdAt: memory.createdAt, updatedAt: memory.updatedAt, syncID: memory.syncID
        )
        let after = existing == nil ? memories + [kept] : memories.map { $0.syncID == memory.syncID ? kept : $0 }
        try await provider.save(after)
        memories = after
    }

    /// Forgets a memory another device deleted. One not held is no change.
    public func deleteRemote(_ syncID: UUID) async throws {
        guard memories.contains(where: { $0.syncID == syncID }) else {
            return
        }
        let after = memories.filter { $0.syncID != syncID }
        try await provider.save(after)
        memories = after
    }

    // MARK: Sync stamps

    /// The memories with each one the ledger changed stamped after the version it replaced, so a change made here
    /// is always later than what it changed, whatever another device's clock said.
    private func stamped(_ memories: [Memory], before: [Memory]) -> [Memory] {
        let previous = Dictionary(before.map { ($0.syncID, $0) }, uniquingKeysWith: { first, _ in first })
        return memories.map { memory in
            guard let old = previous[memory.syncID], old != memory else {
                return memory
            }
            return Memory(
                id: memory.id, text: memory.text, isFromUser: memory.isFromUser, createdAt: memory.createdAt,
                updatedAt: SyncClock.stamp(now: memory.updatedAt, after: old.updatedAt), syncID: memory.syncID
            )
        }
    }

    /// Tells sync which memories were added, changed or forgotten between two lists.
    private func report(from before: [Memory], to after: [Memory]) {
        guard let onLocalChange else {
            return
        }
        let previous = Dictionary(before.map { ($0.syncID, $0) }, uniquingKeysWith: { first, _ in first })
        let remaining = Set(after.map(\.syncID))
        for memory in after where previous[memory.syncID] != memory {
            onLocalChange(.changed(.memory(memory.syncID)))
        }
        for memory in before where !remaining.contains(memory.syncID) {
            onLocalChange(.deleted(.memory(memory.syncID), at: SyncClock.stamp(now: clock(), after: memory.updatedAt)))
        }
    }
}
