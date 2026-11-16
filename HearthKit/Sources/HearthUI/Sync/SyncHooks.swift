import HearthDomain

/// What sync asks of the chat screen, which is built after sync is: whether a chat is being written to, that
/// another device changed some items, and that the hub filed answers to scheduled tasks. The coordinator connects
/// them once the chat exists.
@MainActor
final class SyncHooks {
    var isBusy: (Conversation.ID) -> Bool = { _ in false }
    var didApplyRemote: (Set<SyncItemKey>) -> Void = { _ in }
    var didReceiveTaskResults: ([Conversation.ID]) -> Void = { _ in }
}
