import Foundation
import HearthCore

/// A subject that chats are gathered around. Every chat in a project is given the project's instructions and can
/// draw on its reference files.
public struct Project: Identifiable, Hashable, Codable, Sendable {
    public typealias ID = Tagged<Project, UUID>

    public let id: ID
    public let name: String
    /// Given to the model at the start of every chat in the project, in addition to the user's standing instructions.
    public let instructions: String
    /// Reference files, reduced to their text, that every chat in the project can draw on.
    public let documents: [AttachedDocument]
    public let createdAt: Date
    /// When the project was last changed; the list is ordered by it.
    public let updatedAt: Date

    public init(
        id: ID = ID(UUID()),
        name: String = "",
        instructions: String = "",
        documents: [AttachedDocument] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.instructions = instructions
        self.documents = documents
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// A project saved before a field existed is read with that field's default.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        self.init(
            id: try container.decode(ID.self, forKey: .id),
            name: try container.decodeIfPresent(String.self, forKey: .name) ?? "",
            instructions: try container.decodeIfPresent(String.self, forKey: .instructions) ?? "",
            documents: try container.decodeIfPresent([AttachedDocument].self, forKey: .documents) ?? [],
            createdAt: createdAt,
            updatedAt: try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        )
    }

    /// A copy with the given parts replaced; anything left `nil` is kept.
    public func updating(
        name: String? = nil,
        instructions: String? = nil,
        documents: [AttachedDocument]? = nil,
        updatedAt: Date? = nil
    ) -> Project {
        Project(
            id: id,
            name: name ?? self.name,
            instructions: instructions ?? self.instructions,
            documents: documents ?? self.documents,
            createdAt: createdAt,
            updatedAt: updatedAt ?? self.updatedAt
        )
    }
}

/// Where a conversation is to belong, for `Conversation.updating(project:)`.
///
/// An optional identifier cannot say this there, because a `nil` argument already means "leave it as it is".
public enum ProjectMembership: Hashable, Sendable {
    /// In no project. Not called `none`, which an optional of this type would take for its own "nothing given".
    case noProject
    /// In the project with this identifier.
    case project(Project.ID)

    /// The membership a stored identifier stands for: `nil` is no project.
    public init(_ projectID: Project.ID?) {
        self = projectID.map(Self.project) ?? .noProject
    }

    /// The identifier to store: `nil` for no project.
    public var projectID: Project.ID? {
        switch self {
        case .noProject:
            nil
        case .project(let id):
            id
        }
    }
}
