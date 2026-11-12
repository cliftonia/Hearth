import Foundation
import Observation

/// Whether the chat server answered the last time it was asked for its models.
public enum ServerReachability: Sendable, Equatable {
    /// Not asked yet, or there is no address to ask.
    case unknown
    case reachable
    case unreachable
}

/// The models the server offers, shared by the chat, the sidebar and the settings.
@MainActor
@Observable
public final class ModelStore {
    public private(set) var models: [ChatModel] = []
    public private(set) var reachability: ServerReachability = .unknown

    private let fetchModels: @Sendable (URL) async throws -> [ChatModel]

    public init(fetchModels: @escaping @Sendable (URL) async throws -> [ChatModel]) {
        self.fetchModels = fetchModels
    }

    /// Asks the server for its models, listing those it runs itself first and each group by name.
    public func refresh(settings: ServerSettings) async throws {
        guard let baseURL = settings.ollamaURL else {
            models = []
            reachability = .unknown
            throw ChatError.serverNotConfigured
        }
        do {
            models = try await fetchModels(baseURL).sorted { lhs, rhs in
                (lhs.isCloud ? 1 : 0, lhs.displayName) < (rhs.isCloud ? 1 : 0, rhs.displayName)
            }
            reachability = .reachable
        } catch {
            reachability = .unreachable
            throw ChatError.remapping(error)
        }
    }

    public func model(for id: ChatModel.ID?) -> ChatModel? {
        models.first { $0.id == id }
    }
}
