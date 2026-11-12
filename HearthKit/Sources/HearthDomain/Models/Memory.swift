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
    public let updatedAt: Date

    public init(id: ID, text: String, isFromUser: Bool, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.text = text
        self.isFromUser = isFromUser
        self.createdAt = createdAt
        self.updatedAt = updatedAt
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
