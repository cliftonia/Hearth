import Foundation
import Observation

public enum ServerReachability: Sendable, Equatable {
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
