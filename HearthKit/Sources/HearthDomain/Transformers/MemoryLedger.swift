import Foundation

/// The rules for what may be remembered: short, few, and never the same thing twice.
public struct MemoryLedger: Sendable {
    public static let maximumCount = 50
    public static let maximumLength = 200

    public init() {}

    /// Applies one change and returns the memories as they then stand, with what became of the request.
    public func applying(_ request: MemoryRequest, to memories: [Memory], isFromUser: Bool, now: Date) -> (memories: [Memory], outcome: MemoryOutcome) {
        switch request {
        case .save(let text):
            let fact = normalised(text)
            if let refusal = refusal(for: fact, among: memories) {
                return (memories, .refused(refusal))
            }
            guard memories.count < Self.maximumCount else {
                return (memories, .refused(.full))
            }
            let memory = Memory(id: nextID(after: memories), text: fact, isFromUser: isFromUser, createdAt: now, updatedAt: now)
            return (memories + [memory], .saved(memory))
        case .update(let id, let text):
            guard let existing = memories.first(where: { $0.id == id }) else {
                return (memories, .refused(.notFound))
            }
            let fact = normalised(text)
            if let refusal = refusal(for: fact, among: memories.filter { $0.id != id }) {
                return (memories, .refused(refusal))
            }
            let memory = Memory(id: id, text: fact, isFromUser: isFromUser, createdAt: existing.createdAt, updatedAt: now)
            return (memories.map { $0.id == id ? memory : $0 }, .updated(memory))
        case .delete(let id):
            guard let existing = memories.first(where: { $0.id == id }) else {
                return (memories, .refused(.notFound))
            }
            return (memories.filter { $0.id != id }, .deleted(existing))
        }
    }

    /// One line, trimmed and cut to length.
    private func normalised(_ text: String) -> String {
        String(text.split(whereSeparator: \.isWhitespace).joined(separator: " ").prefix(Self.maximumLength))
    }

    private func refusal(for fact: String, among memories: [Memory]) -> MemoryRefusalKind? {
        if fact.isEmpty {
            return .empty
        }
        let isKnown = memories.contains { $0.text.compare(fact, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
        return isKnown ? .alreadySaved : nil
    }

    /// Handles count upwards and are never reused, so a stale handle cannot point at a newer memory.
    private func nextID(after memories: [Memory]) -> Memory.ID {
        let highest = memories.compactMap { Int($0.id.rawValue.dropFirst()) }.max() ?? 0
        return Memory.ID("m\(highest + 1)")
    }
}
