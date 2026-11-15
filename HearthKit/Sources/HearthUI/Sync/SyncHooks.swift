import HearthDomain

/// What sync asks of the chat screen, which is built after sync is: whether a chat is being written to, and that
/// another device changed some items. The coordinator connects both once the chat exists.
@MainActor
final class SyncHooks {
    var isBusy: (Conversation.ID) -> Bool = { _ in false }
    var didApplyRemote: (Set<SyncItemKey>) -> Void = { _ in }
}
