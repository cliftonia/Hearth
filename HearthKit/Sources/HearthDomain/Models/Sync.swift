import Foundation
import HearthData

/// The kinds of item that are kept in step between devices. Private chats, settings and the profile are never synced.
public enum SyncItemKind: String, Codable, Sendable, CaseIterable {
    case conversation
    case project
    case memory
    /// A scheduled task, which the hub runs and writes back to.
    case task
}

/// Names one synced item: its kind and its lowercase UUID.
public struct SyncItemKey: Hashable, Codable, Sendable {
    public let kind: SyncItemKind
    public let id: String

    public init(kind: SyncItemKind, id: String) {
        self.kind = kind
        self.id = id.lowercased()
    }

    public static func conversation(_ id: Conversation.ID) -> SyncItemKey {
        SyncItemKey(kind: .conversation, id: id.rawValue.uuidString)
    }

    public static func project(_ id: Project.ID) -> SyncItemKey {
        SyncItemKey(kind: .project, id: id.rawValue.uuidString)
    }

    public static func memory(_ syncID: UUID) -> SyncItemKey {
        SyncItemKey(kind: .memory, id: syncID.uuidString)
    }

    public static func task(_ id: ScheduledTask.ID) -> SyncItemKey {
        SyncItemKey(kind: .task, id: id.rawValue.uuidString)
    }

    /// The identifier as a UUID; `nil` if it is not one.
    public var uuid: UUID? { UUID(uuidString: id) }
}

/// Which of two versions of an item is newer: the later time to the millisecond, then the writer that sorts later.
public struct SyncStamp: Hashable, Codable, Sendable, Comparable {
    public let milliseconds: Int64
    /// The opaque install identifier of the device that wrote it, or `hub`.
    public let writer: String

    public init(milliseconds: Int64, writer: String) {
        self.milliseconds = milliseconds
        self.writer = writer
    }

    public init(date: Date, writer: String) {
        self.init(milliseconds: WireTime.milliseconds(of: date), writer: writer)
    }

    public var date: Date { WireTime.date(milliseconds: milliseconds) }

    public static func < (lhs: SyncStamp, rhs: SyncStamp) -> Bool {
        guard lhs.milliseconds == rhs.milliseconds else {
            return lhs.milliseconds < rhs.milliseconds
        }
        // Byte by byte, as the hub and every other platform compare.
        return lhs.writer.utf8.lexicographicallyPrecedes(rhs.writer.utf8)
    }
}

/// Stamps changes so that a change made here is always later than the version it changed.
public enum SyncClock {
    /// The date cut down to a whole millisecond, the precision the wire carries.
    public static func flooredToMillisecond(_ date: Date) -> Date {
        WireTime.date(milliseconds: Int64((date.timeIntervalSince1970 * 1000).rounded(.down)))
    }

    /// The stamp for a change made now to something last stamped `previous`: now, or a millisecond after `previous`
    /// if a device with a fast clock stamped that later than now.
    public static func stamp(now: Date, after previous: Date?) -> Date {
        let now = flooredToMillisecond(now)
        guard let previous else {
            return now
        }
        return max(now, WireTime.date(milliseconds: WireTime.milliseconds(of: previous) + 1))
    }
}

/// What this install remembers about its sync with the hub. It is never synced.
public struct SyncJournal: Codable, Sendable, Hashable {
    /// Opaque, random and made once; it is all the hub learns of this device, as the writer of its changes.
    public var installID: String
    /// The hub database the cursor and stamps below belong to.
    public var hubID: String?
    /// Where the next pull starts.
    public var cursor: Int
    /// For each item, the stamp of the version the hub is known to hold.
    public var seen: [SyncItemKey: SyncStamp]
    /// Deletions made here that the hub has not yet taken.
    public var tombstones: [SyncItemKey: SyncStamp]
    /// Fields of received items that this app does not know, to be given back when it uploads them.
    public var unknownFields: [SyncItemKey: SyncUnknownFieldsDTO]
    public var lastSyncedAt: Date?

    public init(installID: String = UUID().uuidString.lowercased()) {
        self.installID = installID
        self.hubID = nil
        self.cursor = 0
        self.seen = [:]
        self.tombstones = [:]
        self.unknownFields = [:]
        self.lastSyncedAt = nil
    }

    /// Forgets everything that belongs to one hub, as when the address changes or the hub was started afresh.
    /// Deletions still to send are kept: they are as true of the next hub as of the last.
    public mutating func forgetHub() {
        hubID = nil
        cursor = 0
        seen = [:]
        unknownFields = [:]
        lastSyncedAt = nil
    }
}

/// Where the hub is and whether to sync with it. Kept on this device only; the access token is in the Keychain.
public struct SyncSettings: Codable, Sendable, Hashable {
    public var hubAddress: String
    public var isEnabled: Bool

    public init(hubAddress: String = "", isEnabled: Bool = false) {
        self.hubAddress = hubAddress
        self.isEnabled = isEnabled
    }

    /// The hub's address in usable form; `nil` when it is blank or not an address. A bare host is taken to be HTTPS.
    public var hubURL: URL? { ServerSettings.url(from: hubAddress) }

    /// Whether sync runs: it is switched on and has a usable hub address.
    public var isActive: Bool { isEnabled && hubURL != nil }
}

/// Why the last sync did not finish, in terms the status line can put in plain words.
public enum SyncFailureKind: Hashable, Sendable {
    /// No usable hub address.
    case notConfigured
    /// The hub could not be reached.
    case unreachable
    /// The hub wants an access token and none is saved.
    case tokenNeeded
    /// The hub refused the access token.
    case tokenRefused
    /// The hub answered with a failure of its own.
    case hubFailed(status: Int)
    /// The hub answered with something that is not what it should send.
    case unreadable
    /// This many items were too large for the hub and are kept on this device only. The rest synced.
    case tooLarge(count: Int)
}

/// Whether the hub at an address answers, for checking it from the settings.
public enum SyncHubCheckKind: Hashable, Sendable {
    case reachable
    case failed(SyncFailureKind)
}

/// What a store tells sync about a change made on this device. Private chats are never reported.
public enum SyncLocalChangeKind: Hashable, Sendable {
    /// The item was made or changed, and should be uploaded soon.
    case changed(SyncItemKey)
    /// The item was deleted, with the stamp its tombstone is to carry.
    case deleted(SyncItemKey, at: Date)
}
