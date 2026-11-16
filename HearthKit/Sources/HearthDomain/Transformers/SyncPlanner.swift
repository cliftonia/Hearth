import Foundation
import HearthData

/// Decides what a sync does, from stamps alone: which received versions to take, which local ones to keep and
/// upload, which to put off, and where the next pull starts. It holds no state and touches nothing.
///
/// Last writer wins per item: the later `SyncStamp` is kept, and a deletion is a version like any other.
public struct SyncPlanner: Sendable {
    /// What to do with one received version.
    public enum PullDecisionKind: Hashable, Sendable {
        /// Take the received item in place of the local copy, or as a new one.
        case apply
        /// Delete the local copy: the received version is a newer deletion.
        case delete
        /// Keep the local copy or local deletion, which is newer; it is uploaded by the push.
        case keepLocal
        /// Nothing to do: the two are already the same version, or a deletion arrived for something not here.
        case nothing
        /// The local copy is being written (a reply streaming in), so it cannot be replaced now. It is left for
        /// the next sync, which pulls it again.
        case later
    }

    /// What this device holds of one item.
    public struct LocalState: Hashable, Sendable {
        /// The stamp of the local copy; `nil` when there is none.
        public var stamp: SyncStamp?
        /// The stamp of a local deletion not yet uploaded; `nil` when there is none.
        public var tombstone: SyncStamp?
        /// Whether the local copy is being written and must not be replaced.
        public var isBusy: Bool

        public init(stamp: SyncStamp? = nil, tombstone: SyncStamp? = nil, isBusy: Bool = false) {
            self.stamp = stamp
            self.tombstone = tombstone
            self.isBusy = isBusy
        }
    }

    /// The decisions for one page of changes, in its order, and where the next pull is to start.
    public struct PullPlan: Hashable, Sendable {
        public let decisions: [PullDecisionKind]
        public let cursor: Int
        /// Whether something was put off, in which case the cursor stops before it and paging stops too.
        public let isHeldBack: Bool
    }

    /// One upload: an item, or a deletion.
    public struct PushEntry: Hashable, Sendable {
        public let key: SyncItemKey
        public let stamp: SyncStamp
        public let isDeletion: Bool
    }

    public init() {}

    /// The stamp of a local copy last changed at `modifiedAt`. When that is the very millisecond of the version the
    /// hub is known to hold, the copy is that version, writer and all; otherwise it is a change made here.
    public func localStamp(modifiedAt: Date, seen: SyncStamp?, installID: String) -> SyncStamp {
        let milliseconds = WireTime.milliseconds(of: modifiedAt)
        if let seen, seen.milliseconds == milliseconds {
            return seen
        }
        return SyncStamp(milliseconds: milliseconds, writer: installID)
    }

    /// What to do with a received version, given what is held here.
    public func decide(remote: SyncStamp, isDeleted: Bool, local: LocalState) -> PullDecisionKind {
        if let tombstone = local.tombstone, tombstone > remote {
            return .keepLocal
        }
        if let stamp = local.stamp {
            if stamp == remote {
                return .nothing
            }
            if stamp > remote {
                return .keepLocal
            }
            return local.isBusy ? .later : (isDeleted ? .delete : .apply)
        }
        return isDeleted ? .nothing : .apply
    }

    /// The decisions for a page, with `local` saying what is held of each received item (`nil` for kinds this app
    /// does not sync, which are passed over). Once one item has to be put off, the cursor stays before it.
    public func plan(page: SyncChangesDTO, cursor: Int, local: (SyncEnvelopeDTO) -> LocalState?) -> PullPlan {
        var decisions: [PullDecisionKind] = []
        var heldAt: Int?
        for envelope in page.items {
            guard let state = local(envelope) else {
                decisions.append(.nothing)
                continue
            }
            let decision = decide(remote: SyncStamp(date: envelope.updatedAt, writer: envelope.updatedBy), isDeleted: envelope.deleted, local: state)
            if decision == .later, heldAt == nil {
                heldAt = envelope.seq - 1
            }
            decisions.append(decision)
        }
        return PullPlan(decisions: decisions, cursor: heldAt.map { max($0, cursor) } ?? page.next, isHeldBack: heldAt != nil)
    }

    /// Everything to upload: each local item whose version is not the one the hub is known to hold, and each
    /// deletion not yet taken, leaving out anything being written. Projects go before chats, chats before
    /// memories, memories before tasks, and deletions last, a project's after the chats it let go.
    ///
    /// - Parameter local: When each local item last changed. Private chats must not be among them.
    public func pushes(local: [SyncItemKey: Date], journal: SyncJournal, busy: Set<SyncItemKey>) -> [PushEntry] {
        let changed = local.compactMap { key, modifiedAt -> PushEntry? in
            let stamp = localStamp(modifiedAt: modifiedAt, seen: journal.seen[key], installID: journal.installID)
            guard journal.seen[key] != stamp, !busy.contains(key), journal.tombstones[key] == nil else {
                return nil
            }
            return PushEntry(key: key, stamp: stamp, isDeletion: false)
        }
        let deletions = journal.tombstones.compactMap { key, stamp -> PushEntry? in
            journal.seen[key] == stamp ? nil : PushEntry(key: key, stamp: stamp, isDeletion: true)
        }
        return changed.sorted(by: Self.order) + deletions.sorted(by: Self.deletionOrder)
    }

    /// Uploads in order: projects, then chats, then memories, then tasks.
    private static func rank(_ kind: SyncItemKind) -> Int {
        switch kind {
        case .project:
            0
        case .conversation:
            1
        case .memory:
            2
        case .task:
            3
        }
    }

    /// Deletions in order: chats, then memories, then tasks, then projects, so a project goes after the chats it let go.
    private static func deletionRank(_ kind: SyncItemKind) -> Int {
        switch kind {
        case .conversation:
            0
        case .memory:
            1
        case .task:
            2
        case .project:
            3
        }
    }

    private static func order(_ lhs: PushEntry, _ rhs: PushEntry) -> Bool {
        (rank(lhs.key.kind), lhs.key.id) < (rank(rhs.key.kind), rhs.key.id)
    }

    private static func deletionOrder(_ lhs: PushEntry, _ rhs: PushEntry) -> Bool {
        (deletionRank(lhs.key.kind), lhs.key.id) < (deletionRank(rhs.key.kind), rhs.key.id)
    }
}
