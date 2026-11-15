import Foundation
import HearthData

public extension Memory {
    /// A memory from its synced body. The short handle is this device's own and is given by the caller.
    ///
    /// - Parameters:
    ///   - handle: The handle the memory has, or is to have, on this device.
    ///   - updatedAt: The envelope's `updatedAt`.
    init(from dto: MemoryBodyDTO, handle: Memory.ID, syncID: UUID, updatedAt: Date) {
        self.init(id: handle, text: dto.text, isFromUser: dto.isFromUser ?? false, createdAt: dto.createdAt, updatedAt: updatedAt, syncID: syncID)
    }
}

public extension MemoryBodyDTO {
    init(from memory: Memory) {
        self.init(schema: SyncWire.schema, text: memory.text, isFromUser: memory.isFromUser, createdAt: memory.createdAt)
    }
}
