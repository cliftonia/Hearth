import Foundation
import HearthData

public extension Project {
    /// A project from its synced body.
    ///
    /// - Parameter updatedAt: The envelope's `updatedAt`, which is when the project last changed.
    init(from dto: ProjectBodyDTO, id: Project.ID, updatedAt: Date) {
        self.init(
            id: id,
            name: dto.name ?? "",
            instructions: dto.instructions ?? "",
            documents: (dto.documents ?? []).map(AttachedDocument.init(from:)),
            createdAt: dto.createdAt,
            updatedAt: updatedAt
        )
    }
}

public extension ProjectBodyDTO {
    init(from project: Project) {
        self.init(
            schema: SyncWire.schema,
            name: project.name,
            instructions: project.instructions,
            documents: project.documents.map(DocumentDTO.init(from:)),
            createdAt: project.createdAt
        )
    }
}
