import Foundation

/// The changes the stores make to the list they hold and to disk together: shown at once, and undone if the
/// write fails. Shared by `ConversationStore`, `ProjectStore` and `TaskStore`.
@MainActor
extension SavedItemDataProvider {
    /// Takes any copy of `item` out of the list, lets `place` put the item back in, and writes it to disk.
    ///
    /// If the write fails the item goes back to how it was, at its old place, or out of the list if it was new, and
    /// the error is passed on.
    func write<Owner: AnyObject>(
        _ item: Item,
        into list: ReferenceWritableKeyPath<Owner, [Item]>,
        of owner: Owner,
        placing place: ([Item], Item) -> [Item]
    ) async throws {
        let before = owner[keyPath: list]
        let previousIndex = before.firstIndex { $0.id == item.id }
        owner[keyPath: list] = place(before.filter { $0.id != item.id }, item)
        do {
            try await save(item)
        } catch {
            var restored = owner[keyPath: list].filter { $0.id != item.id }
            if let previousIndex {
                restored.insert(before[previousIndex], at: min(previousIndex, restored.count))
            }
            owner[keyPath: list] = restored
            throw error
        }
    }

    /// Takes the item out of the list and deletes it from disk. If it cannot be deleted it goes back to its place,
    /// and the error is passed on. One not in the list is still deleted from disk.
    ///
    /// - Returns: The item removed, or `nil` if it was not in the list.
    @discardableResult
    func remove<Owner: AnyObject>(
        _ id: Item.ID,
        from list: ReferenceWritableKeyPath<Owner, [Item]>,
        of owner: Owner
    ) async throws -> Item? {
        guard let index = owner[keyPath: list].firstIndex(where: { $0.id == id }) else {
            try await delete(id)
            return nil
        }
        let removed = owner[keyPath: list].remove(at: index)
        do {
            try await delete(id)
        } catch {
            owner[keyPath: list].insert(removed, at: min(index, owner[keyPath: list].count))
            throw error
        }
        return removed
    }

    /// Deletes everything from disk and empties the list. If that cannot be done, `reload` reads the list again
    /// from what is left on disk, and the error is passed on.
    func removeAll<Owner: AnyObject>(
        from list: ReferenceWritableKeyPath<Owner, [Item]>,
        of owner: Owner,
        reload: () async throws -> Void
    ) async throws {
        do {
            try await deleteAll()
            owner[keyPath: list] = []
        } catch {
            try? await reload()
            throw error
        }
    }
}
