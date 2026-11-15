import Foundation
import HearthCore

/// One lasting fact remembered about the user, carried into every conversation.
public struct Memory: Identifiable, Hashable, Codable, Sendable {
    public typealias ID = Tagged<Memory, String>

    /// A short handle such as `m3`, easy for a small model to quote back.
    public let id: ID
    public let text: String
    /// Whether the user wrote it by hand, rather than the model saving it.
    public let isFromUser: Bool
    public let createdAt: Date
    /// When the memory last changed; sync compares it to decide which of two copies is newer.
    public let updatedAt: Date
    /// Names the memory between devices. The short handle cannot, since every device counts its own from `m1`.
    public let syncID: UUID

    public init(id: ID, text: String, isFromUser: Bool, createdAt: Date, updatedAt: Date, syncID: UUID = UUID()) {
        self.id = id
        self.text = text
        self.isFromUser = isFromUser
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncID = syncID
    }

    /// Memories saved before sync have no `syncID` and are given one; `MemoryDataProvider` writes it back at once,
    /// so that it never changes.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(ID.self, forKey: .id),
            text: try container.decode(String.self, forKey: .text),
            isFromUser: try container.decode(Bool.self, forKey: .isFromUser),
            createdAt: try container.decode(Date.self, forKey: .createdAt),
            updatedAt: try container.decode(Date.self, forKey: .updatedAt),
            syncID: try container.decodeIfPresent(UUID.self, forKey: .syncID) ?? UUID()
        )
    }
}

/// A change to what is remembered.
public enum MemoryRequest: Sendable, Equatable {
    case save(String)
    case update(Memory.ID, String)
    case delete(Memory.ID)
}

/// What became of a request to change what is remembered.
public enum MemoryOutcome: Sendable, Equatable {
    case saved(Memory)
    case updated(Memory)
    case deleted(Memory)
    case refused(MemoryRefusalKind)
}

/// Why a change to what is remembered was turned down.
public enum MemoryRefusalKind: Sendable, Equatable {
    /// There was no text to remember.
    case empty
    /// The same fact is already remembered.
    case alreadySaved
    /// There is no room for another memory.
    case full
    /// No memory has the given handle.
    case notFound
    /// The memory was written by the user, and a model may not change or forget it.
    case writtenByUser
    /// The change could not be written to disk.
    case notStored
}
