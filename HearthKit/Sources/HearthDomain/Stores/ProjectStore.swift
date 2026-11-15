import Foundation
import Observation

/// Every saved project, most recently changed first, shared by the chat list, the chat and the project sheets.
@MainActor
@Observable
public final class ProjectStore {
    public private(set) var projects: [Project] = []
    /// Told of every change made on this device, for sync. Not told of erasing everything.
    @ObservationIgnored public var onLocalChange: (@MainActor (SyncLocalChangeKind) -> Void)?

    let provider: ProjectDataProvider
    private let clock: @MainActor () -> Date

    /// - Parameter clock: The time changes are stamped with.
    public init(provider: ProjectDataProvider, clock: @escaping @MainActor () -> Date = { Date() }) {
        self.provider = provider
        self.clock = clock
    }

    /// Reads every project from disk, most recently changed first.
    public func load() async throws {
        projects = try await provider.loadAll().sorted { $0.updatedAt > $1.updatedAt }
    }

    /// The project with the given identifier. `nil` for no identifier, and for one whose project has been deleted.
    public func project(for id: Project.ID?) -> Project? {
        guard let id else {
            return nil
        }
        return projects.first { $0.id == id }
    }

    /// Puts a new or changed project at the top of the list and writes it to disk.
    ///
    /// It is stamped as changed now, which is also when the list says it last changed. If the write fails the list
    /// goes back to what is on disk, and the error is passed on.
    public func save(_ project: Project) async throws {
        let previousIndex = projects.firstIndex { $0.id == project.id }
        let previous = previousIndex.map { projects[$0] }
        let project = project.updating(updatedAt: SyncClock.stamp(now: clock(), after: previous?.updatedAt))
        projects.removeAll { $0.id == project.id }
        projects.insert(project, at: 0)
        do {
            try await provider.save(project)
        } catch {
            projects.removeAll { $0.id == project.id }
            if let previous, let previousIndex {
                projects.insert(previous, at: min(previousIndex, projects.count))
            }
            throw error
        }
        onLocalChange?(.changed(.project(project.id)))
    }

    /// Removes every project from the list and from disk, as when the user erases everything on the device.
    /// Sync is not told: erasing this device deletes nothing anywhere else.
    /// If that cannot be done the list is read again from what is left on disk, and the error is passed on.
    public func deleteAll() async throws {
        do {
            if let deleteAll = provider.deleteAll {
                try await deleteAll()
            } else {
                for project in projects {
                    try await provider.delete(project.id)
                }
            }
            projects = []
        } catch {
            try? await load()
            throw error
        }
    }

    /// Removes a project from the list and from disk. If it cannot be removed from disk it stays in the list.
    ///
    /// The project's chats are not touched here; `ProjectInteractor` lets them go first.
    public func delete(_ id: Project.ID) async throws {
        guard let index = projects.firstIndex(where: { $0.id == id }) else {
            try await provider.delete(id)
            return
        }
        let removed = projects.remove(at: index)
        do {
            try await provider.delete(id)
        } catch {
            projects.insert(removed, at: min(index, projects.count))
            throw error
        }
        onLocalChange?(.deleted(.project(id), at: SyncClock.stamp(now: clock(), after: removed.updatedAt)))
    }

    // MARK: From another device

    /// Puts a project from another device in the list, in its place by date, replacing any copy held. It is
    /// written as it came, stamp included, and sync is not told.
    public func applyRemote(_ project: Project) async throws {
        try await provider.save(project)
        projects.removeAll { $0.id == project.id }
        projects.insert(project, at: projects.firstIndex { $0.updatedAt < project.updatedAt } ?? projects.count)
    }

    /// Removes a project another device deleted. Its chats are let go by `ConversationStore.releaseRemote(from:)`.
    public func deleteRemote(_ id: Project.ID) async throws {
        guard projects.contains(where: { $0.id == id }) else {
            return
        }
        try await provider.delete(id)
        projects.removeAll { $0.id == id }
    }
}
