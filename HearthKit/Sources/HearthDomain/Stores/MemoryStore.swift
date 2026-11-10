import Foundation
import Observation

/// What is remembered about the user, shared by the chat and the settings.
@MainActor
@Observable
public final class MemoryStore {
    public private(set) var memories: [Memory] = []

    private let provider: MemoryDataProvider
    private let ledger = MemoryLedger()

    public init(provider: MemoryDataProvider) {
        self.provider = provider
    }

    public func load() async throws {
        memories = try await provider.load()
    }

    /// Applies a change and writes it to disk. A change that could not be written is undone and reported as refused.
    @discardableResult
    public func apply(_ request: MemoryRequest, isFromUser: Bool) async -> MemoryOutcome {
        let before = memories
        let result = ledger.applying(request, to: memories, isFromUser: isFromUser, now: Date())
        guard result.memories != before else {
            return result.outcome
        }
        memories = result.memories
        do {
            try await provider.save(result.memories)
            return result.outcome
        } catch {
            memories = before
            return .refused(.notStored)
        }
    }

    public func clear() async throws {
        let before = memories
        memories = []
        do {
            try await provider.save([])
        } catch {
            memories = before
            throw error
        }
    }
}
