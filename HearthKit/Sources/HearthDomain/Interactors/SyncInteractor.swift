import Foundation
import HearthCore
import HearthData
import os

/// Why a sync stopped, in words the status line can use.
public struct SyncError: Error, Sendable, Equatable {
    public let failure: SyncFailureKind

    public init(_ failure: SyncFailureKind) {
        self.failure = failure
    }
}

/// Keeps this device's chats, projects, memories and scheduled tasks in step with a Hearth Hub: one sync is a pull of what changed
/// on the hub, applied through the stores, then a push of what changed here.
///
/// What to do with each item is `SyncPlanner`'s decision; this carries it out. Private chats are never read for
/// sending, and a chat whose reply is still being written is neither replaced nor sent until it is finished. The
/// logs hold counts and kinds of failure, never a title, a message, an address or a token.
public final class SyncInteractor: Sendable {
    /// The stores sync reads and changes.
    public struct Stores: Sendable {
        public let conversations: ConversationStore
        public let projects: ProjectStore
        public let memories: MemoryStore
        public let tasks: TaskStore
        public let sync: SyncStore

        public init(conversations: ConversationStore, projects: ProjectStore, memories: MemoryStore, tasks: TaskStore, sync: SyncStore) {
            self.conversations = conversations
            self.projects = projects
            self.memories = memories
            self.tasks = tasks
            self.sync = sync
        }
    }

    let stores: Stores
    let provider: SyncDataProvider
    let planner = SyncPlanner()
    /// Whether a chat is being written to right now, as while a reply streams in.
    let isBusy: @MainActor @Sendable (Conversation.ID) -> Bool
    /// Told which items another device's changes were applied to, so a screen showing one can show the new copy.
    let didApplyRemote: @MainActor @Sendable (Set<SyncItemKey>) -> Void
    /// Told of chats the hub filed for a scheduled task that arrived new to this device, in a sync that was not
    /// catching up from the start, so that each answer can be announced once.
    let didReceiveTaskResults: @MainActor @Sendable ([Conversation.ID]) -> Void
    let logger = Logger(for: SyncInteractor.self)

    public init(
        stores: Stores,
        provider: SyncDataProvider,
        isBusy: @escaping @MainActor @Sendable (Conversation.ID) -> Bool = { _ in false },
        didApplyRemote: @escaping @MainActor @Sendable (Set<SyncItemKey>) -> Void = { _ in },
        didReceiveTaskResults: @escaping @MainActor @Sendable ([Conversation.ID]) -> Void = { _ in }
    ) {
        self.stores = stores
        self.provider = provider
        self.isBusy = isBusy
        self.didApplyRemote = didApplyRemote
        self.didReceiveTaskResults = didReceiveTaskResults
    }

    /// Runs one sync: pull, then push. Returns how many items were too large to send, which stay on this device.
    ///
    /// - Throws: `SyncError` saying what went wrong, or `CancellationError` if the sync was stopped.
    @MainActor
    @discardableResult
    public func sync() async throws -> Int {
        guard let url = stores.sync.settings.hubURL else {
            throw SyncError(.notConfigured)
        }
        let token = stores.sync.token()
        do {
            try await pull(from: url, token: token)
            let tooLarge = try await push(to: url, token: token)
            stores.sync.persistJournal()
            return tooLarge
        } catch {
            stores.sync.persistJournal()
            throw Self.syncError(for: error, hasToken: token != nil)
        }
    }

    /// Checks the hub at an address: that it answers, and that the token, or the lack of one, is let in.
    @MainActor
    public func check(_ url: URL, token: String?) async -> SyncHubCheckKind {
        do {
            let health = try await provider.health(url)
            _ = try await provider.changes(url, token, health.seq)
            return .reachable
        } catch {
            let failure = (Self.syncError(for: error, hasToken: token != nil) as? SyncError)?.failure ?? .unreachable
            logger.notice("Checking the hub failed: \(String(describing: failure), privacy: .public)")
            return .failed(failure)
        }
    }

    // MARK: Pull

    /// Takes every change on the hub after the saved cursor, page by page, saving the cursor after each.
    ///
    /// A pull from the start (a first sync, or a hub started afresh) brings in every answer a task ever filed, so
    /// only a pull that carries on from a cursor reports new ones.
    @MainActor
    private func pull(from url: URL, token: String?) async throws {
        var applied = 0
        var isCatchingUp = stores.sync.journal.cursor == 0
        var taskResults: [Conversation.ID] = []
        while true {
            let cursor = stores.sync.journal.cursor
            let page = try await provider.changes(url, token, cursor)
            try Task.checkCancellation()
            guard page.hubId == stores.sync.journal.hubID || stores.sync.journal.hubID == nil && cursor == 0 else {
                // Another hub, or this one started afresh: start again from nothing, as on first contact.
                logger.notice("The hub's database changed; syncing from the start")
                stores.sync.updateJournal { $0.forgetHub() }
                isCatchingUp = true
                continue
            }
            stores.sync.updateJournal { $0.hubID = page.hubId }
            let plan = planner.plan(page: page, cursor: cursor) { self.localState(for: $0) }
            var changed = Set<SyncItemKey>()
            for (envelope, decision) in zip(page.items, plan.decisions) {
                let wasHeld = isHeldHere(envelope)
                if let key = try await carryOut(decision, for: envelope) {
                    changed.insert(key)
                    if !wasHeld, !isCatchingUp, let id = newTaskResult(key) {
                        taskResults.append(id)
                    }
                }
            }
            applied += changed.count
            stores.sync.updateJournal { $0.cursor = plan.cursor }
            stores.sync.persistJournal()
            didApplyRemote(changed)
            guard page.hasMore, !plan.isHeldBack else {
                break
            }
        }
        logger.info("Pulled changes; applied \(applied, privacy: .public)")
        if !taskResults.isEmpty {
            didReceiveTaskResults(taskResults)
        }
    }

    /// Whether this device already holds the conversation an envelope is about. Only conversations matter here.
    @MainActor
    private func isHeldHere(_ envelope: SyncEnvelopeDTO) -> Bool {
        guard envelope.kind == SyncItemKind.conversation.rawValue, let uuid = UUID(uuidString: envelope.id) else {
            return true
        }
        return stores.conversations.conversation(for: Conversation.ID(uuid)) != nil
    }

    /// The conversation a key names, if it is now held here and was filed by a scheduled task.
    @MainActor
    private func newTaskResult(_ key: SyncItemKey) -> Conversation.ID? {
        guard key.kind == .conversation, let uuid = key.uuid else {
            return nil
        }
        let id = Conversation.ID(uuid)
        return stores.conversations.conversation(for: id)?.taskID == nil ? nil : id
    }

    /// The error to report for one that ended a sync.
    static func syncError(for error: any Error, hasToken: Bool) -> any Error {
        switch error {
        case is CancellationError, is SyncError:
            return error
        case HTTPError.status(let code, _) where code == 401:
            return SyncError(hasToken ? .tokenRefused : .tokenNeeded)
        case HTTPError.status(let code, _):
            return SyncError(.hubFailed(status: code))
        case is URLError:
            if (error as? URLError)?.code == .cancelled {
                return CancellationError()
            }
            return SyncError(.unreachable)
        default:
            return SyncError(.unreadable)
        }
    }
}
