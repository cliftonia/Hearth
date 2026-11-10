import Foundation
import HearthCore

/// A model the server can chat with.
public struct ChatModel: Identifiable, Hashable, Codable, Sendable {
    public typealias ID = Tagged<ChatModel, String>

    public let id: ID
    public let isCloud: Bool
    public let parameterSize: String?
    public let canThink: Bool
    public let canSee: Bool
    /// Whether the model can call tools, and so decide for itself when to search the web.
    public let canUseTools: Bool

    public init(
        id: ID,
        isCloud: Bool = false,
        parameterSize: String? = nil,
        canThink: Bool = false,
        canSee: Bool = false,
        canUseTools: Bool = false
    ) {
        self.id = id
        self.isCloud = isCloud
        self.parameterSize = parameterSize
        self.canThink = canThink
        self.canSee = canSee
        self.canUseTools = canUseTools
    }

    /// The name without the tags that say nothing to a reader, such as `:latest`.
    public var displayName: String {
        var name = id.rawValue
        for suffix in [":latest", ":cloud"] where name.hasSuffix(suffix) {
            name.removeLast(suffix.count)
        }
        return name.split(separator: "/").last.map(String.init) ?? name
    }
}
