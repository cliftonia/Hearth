import Foundation
import Observation

/// Every scheduled task this device knows of, oldest first, kept in step with the hub by sync.
///
/// Tasks are run by the hub, which writes back when each last ran; those changes arrive through `applyRemote` like
/// any other device's. A change made here is stamped and reported, exactly as `ProjectStore` does.
@MainActor
@Observable
public final class TaskStore {
    public private(set) var tasks: [ScheduledTask] = []
    /// Told of every change made on this device, for sync. Not told of erasing everything.
    @ObservationIgnored public var onLocalChange: (@MainActor (SyncLocalChangeKind) -> Void)?

    let provider: TaskDataProvider
    private let clock: @MainActor () -> Date

    /// - Parameter clock: The time changes are stamped with.
    public init(provider: TaskDataProvider, clock: @escaping @MainActor () -> Date = { Date() }) {
        self.provider = provider
        self.clock = clock
    }

    /// Reads every task from disk.
    public func load() async throws {
        tasks = Self.ordered(try await provider.loadAll())
    }

    /// The task with the given identifier; `nil` for one that has been deleted.
    public func task(for id: ScheduledTask.ID) -> ScheduledTask? {
        tasks.first { $0.id == id }
    }

    /// Keeps a new or changed task, stamped as changed now. If the write fails the list goes back to how it was,
    /// and the error is passed on.
    public func save(_ task: ScheduledTask) async throws {
        let previous = self.task(for: task.id)
        let task = task.stamped(at: SyncClock.stamp(now: clock(), after: previous?.updatedAt))
        let before = tasks
        tasks = Self.ordered(tasks.filter { $0.id != task.id } + [task])
        do {
            try await provider.save(task)
        } catch {
            tasks = before
            throw error
        }
        onLocalChange?(.changed(.task(task.id)))
    }

    /// Removes a task from the list and from disk; the hub stops running it once sync sends the deletion. If it
    /// cannot be removed from disk it stays in the list.
    public func delete(_ id: ScheduledTask.ID) async throws {
        guard let removed = task(for: id) else {
            try await provider.delete(id)
            return
        }
        let before = tasks
        tasks.removeAll { $0.id == id }
        do {
            try await provider.delete(id)
        } catch {
            tasks = before
            throw error
        }
        onLocalChange?(.deleted(.task(id), at: SyncClock.stamp(now: clock(), after: removed.updatedAt)))
    }

    /// Removes every task from this device, as erasing everything does. The hub keeps them and sync is not told.
    public func deleteAll() async throws {
        do {
            if let deleteAll = provider.deleteAll {
                try await deleteAll()
            } else {
                for task in tasks {
                    try await provider.delete(task.id)
                }
            }
            tasks = []
        } catch {
            try? await load()
            throw error
        }
    }

    // MARK: From the hub and other devices

    /// Puts a task from the hub in the list, replacing any copy held. It is written as it came, stamp included,
    /// and sync is not told.
    public func applyRemote(_ task: ScheduledTask) async throws {
        try await provider.save(task)
        tasks = Self.ordered(tasks.filter { $0.id != task.id } + [task])
    }

    /// Removes a task deleted elsewhere.
    public func deleteRemote(_ id: ScheduledTask.ID) async throws {
        guard task(for: id) != nil else {
            return
        }
        try await provider.delete(id)
        tasks.removeAll { $0.id == id }
    }

    /// Oldest first, so a task keeps its place in the list however often it runs or is changed.
    private static func ordered(_ tasks: [ScheduledTask]) -> [ScheduledTask] {
        tasks.sorted { ($0.createdAt, $0.id.rawValue.uuidString) < ($1.createdAt, $1.id.rawValue.uuidString) }
    }
}
