import Foundation
import HearthData

// Reading items from the stores, applying received ones to them, and pushing what changed here.
extension SyncInteractor {
    // MARK: Push

    /// Sends every local change the hub does not yet hold. Returns how many were too large to send.
    @MainActor
    func push(to url: URL, token: String?) async throws -> Int {
        let busy = Set(stores.conversations.conversations.filter { isBusy($0.id) }.map { SyncItemKey.conversation($0.id) })
        let entries = planner.pushes(local: localItems(), journal: stores.sync.journal, busy: busy)
        var tooLarge = 0
        var adopted = Set<SyncItemKey>()
        for entry in entries {
            try Task.checkCancellation()
            guard let change = try await change(for: entry) else {
                continue
            }
            switch try await provider.put(url, token, entry.key, change) {
            case .accepted:
                stores.sync.updateJournal { journal in
                    journal.seen[entry.key] = entry.stamp
                    if entry.isDeletion {
                        journal.tombstones[entry.key] = nil
                    }
                }
            case .conflict(let newer):
                // The hub holds a later version: take it, unless this device has changed the item again since.
                let decision = planner.decide(
                    remote: SyncStamp(date: newer.updatedAt, writer: newer.updatedBy), isDeleted: newer.deleted, local: localState(for: newer) ?? .init()
                )
                if let key = try await carryOut(decision, for: newer) {
                    adopted.insert(key)
                }
            case .tooLarge:
                tooLarge += 1
            }
            stores.sync.persistJournal()
        }
        didApplyRemote(adopted)
        logger.info("Pushed \(entries.count, privacy: .public); adopted \(adopted.count, privacy: .public); too large \(tooLarge, privacy: .public)")
        return tooLarge
    }

    /// When each item that may be sent last changed. Private chats are left out here, before anything else.
    @MainActor
    func localItems() -> [SyncItemKey: Date] {
        var items: [SyncItemKey: Date] = [:]
        for conversation in stores.conversations.conversations where !conversation.isPrivate {
            items[.conversation(conversation.id)] = conversation.modifiedAt
        }
        for project in stores.projects.projects {
            items[.project(project.id)] = project.updatedAt
        }
        for memory in stores.memories.memories {
            items[.memory(memory.syncID)] = memory.updatedAt
        }
        return items
    }

    /// The body to send for one entry, built away from the main actor since a chat with pictures is large;
    /// `nil` if the item has gone since the plan was made.
    @MainActor
    private func change(for entry: SyncPlanner.PushEntry) async throws -> SyncPutDTO? {
        guard !entry.isDeletion else {
            return SyncPutDTO(updatedAt: entry.stamp.date, updatedBy: entry.stamp.writer, deleted: true, body: nil)
        }
        let unknown = stores.sync.journal.unknownFields[entry.key]
        let uuid = entry.key.uuid
        let written: JSONValue?
        switch entry.key.kind {
        case .conversation:
            let conversation = uuid.flatMap { stores.conversations.conversation(for: Conversation.ID($0)) }
            guard let conversation, !conversation.isPrivate else {
                return nil
            }
            written = try await Task.detached { try SyncWire.json(from: ConversationBodyDTO(from: conversation)) }.value
        case .project:
            written = try (uuid.flatMap { stores.projects.project(for: Project.ID($0)) }).map { try SyncWire.json(from: ProjectBodyDTO(from: $0)) }
        case .memory:
            written = try (stores.memories.memories.first { $0.syncID == uuid }).map { try SyncWire.json(from: MemoryBodyDTO(from: $0)) }
        }
        guard let written else {
            return nil
        }
        let body = unknown.map { $0.merged(into: written) } ?? written
        return SyncPutDTO(updatedAt: entry.stamp.date, updatedBy: entry.stamp.writer, deleted: false, body: body)
    }

    // MARK: Pull

    /// What this device holds of a received item; `nil` for a kind it does not sync or an identifier that is not
    /// a UUID, and for anything that would touch a private chat.
    @MainActor
    func localState(for envelope: SyncEnvelopeDTO) -> SyncPlanner.LocalState? {
        guard let kind = SyncItemKind(rawValue: envelope.kind), let uuid = UUID(uuidString: envelope.id) else {
            return nil
        }
        let key = SyncItemKey(kind: kind, id: envelope.id)
        let journal = stores.sync.journal
        let modifiedAt: Date?
        var isBusy = false
        switch kind {
        case .conversation:
            let conversation = stores.conversations.conversation(for: Conversation.ID(uuid))
            if conversation?.isPrivate == true {
                return nil
            }
            modifiedAt = conversation?.modifiedAt
            isBusy = conversation != nil && self.isBusy(Conversation.ID(uuid))
        case .project:
            modifiedAt = stores.projects.project(for: Project.ID(uuid))?.updatedAt
        case .memory:
            modifiedAt = stores.memories.memories.first { $0.syncID == uuid }?.updatedAt
        }
        let stamp = modifiedAt.map { planner.localStamp(modifiedAt: $0, seen: journal.seen[key], installID: journal.installID) }
        return SyncPlanner.LocalState(stamp: stamp, tombstone: journal.tombstones[key], isBusy: isBusy)
    }

    /// Carries out one decision about a received item and notes it in the journal. Returns the item's key if a
    /// store was changed.
    @MainActor
    func carryOut(_ decision: SyncPlanner.PullDecisionKind, for envelope: SyncEnvelopeDTO) async throws -> SyncItemKey? {
        guard let kind = SyncItemKind(rawValue: envelope.kind), let uuid = UUID(uuidString: envelope.id) else {
            return nil
        }
        let key = SyncItemKey(kind: kind, id: envelope.id)
        let stamp = SyncStamp(date: envelope.updatedAt, writer: envelope.updatedBy)
        switch decision {
        case .later:
            return nil
        case .keepLocal:
            stores.sync.updateJournal { $0.seen[key] = stamp }
            return nil
        case .nothing:
            stores.sync.updateJournal { journal in
                journal.seen[key] = stamp
                if envelope.deleted {
                    journal.tombstones[key] = nil
                }
            }
            return nil
        case .delete:
            try await delete(kind, uuid: uuid)
            stores.sync.updateJournal { journal in
                journal.seen[key] = stamp
                journal.tombstones[key] = nil
                journal.unknownFields[key] = nil
            }
            return key
        case .apply:
            return try await apply(envelope, key: key, uuid: uuid) ? key : nil
        }
    }

    @MainActor
    private func delete(_ kind: SyncItemKind, uuid: UUID) async throws {
        switch kind {
        case .conversation:
            try await stores.conversations.deleteRemote(Conversation.ID(uuid))
        case .project:
            try await stores.conversations.releaseRemote(from: Project.ID(uuid))
            try await stores.projects.deleteRemote(Project.ID(uuid))
        case .memory:
            try await stores.memories.deleteRemote(uuid)
        }
    }

    /// Writes a received item through its store. A body this app cannot read is passed over and left out of the
    /// journal, so the local copy is neither replaced nor sent over it; the reason is logged.
    @MainActor
    private func apply(_ envelope: SyncEnvelopeDTO, key: SyncItemKey, uuid: UUID) async throws -> Bool {
        let body = envelope.body ?? .object([:])
        let item: ReceivedItem
        do {
            item = try await Task.detached { try ReceivedItem(kind: key.kind, uuid: uuid, body: body, updatedAt: envelope.updatedAt) }.value
        } catch {
            logger.error("A received \(key.kind.rawValue, privacy: .public) could not be read: \(String(describing: error), privacy: .public)")
            return false
        }
        switch item {
        case .conversation(let conversation):
            try await stores.conversations.applyRemote(conversation)
        case .project(let project):
            try await stores.projects.applyRemote(project)
        case .memory(let memory):
            try await stores.memories.applyRemote(memory)
        }
        let unknown = SyncUnknownFieldsDTO(from: body, known: ReceivedItem.knownFields(of: key.kind))
        stores.sync.updateJournal { journal in
            journal.seen[key] = SyncStamp(date: envelope.updatedAt, writer: envelope.updatedBy)
            journal.tombstones[key] = nil
            journal.unknownFields[key] = unknown.isEmpty ? nil : unknown
        }
        return true
    }
}

/// A received item read into the app's models.
private enum ReceivedItem: Sendable {
    case conversation(Conversation)
    case project(Project)
    case memory(Memory)

    init(kind: SyncItemKind, uuid: UUID, body: JSONValue, updatedAt: Date) throws {
        switch kind {
        case .conversation:
            let dto = try SyncWire.decode(ConversationBodyDTO.self, from: body)
            self = .conversation(try Conversation(from: dto, id: Conversation.ID(uuid), modifiedAt: updatedAt))
        case .project:
            self = .project(Project(from: try SyncWire.decode(ProjectBodyDTO.self, from: body), id: Project.ID(uuid), updatedAt: updatedAt))
        case .memory:
            // The handle is the store's to give; this one is a stand-in.
            let dto = try SyncWire.decode(MemoryBodyDTO.self, from: body)
            self = .memory(Memory(from: dto, handle: Memory.ID(""), syncID: uuid, updatedAt: updatedAt))
        }
    }

    static func knownFields(of kind: SyncItemKind) -> Set<String> {
        switch kind {
        case .conversation:
            SyncWire.conversationFields
        case .project:
            SyncWire.projectFields
        case .memory:
            SyncWire.memoryFields
        }
    }
}
