import Foundation
import HearthData

/// Whether the system lets the app post notifications.
public enum NotificationPermissionKind: Hashable, Sendable {
    /// The user has not been asked yet.
    case notDetermined
    case allowed
    case denied
}

/// A notification that a reply is ready, as it is posted.
public struct ReplyNotification: Hashable, Sendable {
    /// The chat the reply is in, which a tap opens.
    public let conversationID: Conversation.ID
    public let title: String
    public let body: String

    public init(conversationID: Conversation.ID, title: String, body: String) {
        self.conversationID = conversationID
        self.title = title
        self.body = body
    }
}

/// How the domain posts local notifications and hears of the ones that are tapped.
public struct NotificationProvider: Sendable {
    public let permission: @Sendable () async -> NotificationPermissionKind
    /// Asks the user to allow notifications and returns whether they are allowed. The system asks only once.
    public let requestPermission: @Sendable () async -> Bool
    public let post: @Sendable (ReplyNotification) async throws -> Void
    /// Takes down everything the app has posted.
    public let removeAll: @Sendable () async -> Void
    /// The chat of each notification the user taps.
    public let taps: @Sendable () -> AsyncStream<Conversation.ID>

    public init(
        permission: @escaping @Sendable () async -> NotificationPermissionKind,
        requestPermission: @escaping @Sendable () async -> Bool,
        post: @escaping @Sendable (ReplyNotification) async throws -> Void,
        removeAll: @escaping @Sendable () async -> Void = {},
        taps: @escaping @Sendable () -> AsyncStream<Conversation.ID> = { AsyncStream { $0.finish() } }
    ) {
        self.permission = permission
        self.requestPermission = requestPermission
        self.post = post
        self.removeAll = removeAll
        self.taps = taps
    }
}

public extension NotificationProvider {
    /// Backed by the system's local notifications. Making it begins listening for taps.
    static func live(service: NotificationService = NotificationService()) -> NotificationProvider {
        service.activate()
        return NotificationProvider(
            permission: {
                switch await service.permission() {
                case .notDetermined:
                    .notDetermined
                case .allowed:
                    .allowed
                case .denied:
                    .denied
                }
            },
            requestPermission: { await service.requestPermission() },
            post: { notification in
                try await service.post(
                    title: notification.title,
                    body: notification.body,
                    subject: notification.conversationID.rawValue.uuidString
                )
            },
            removeAll: { service.removeAll() },
            taps: {
                AsyncStream { continuation in
                    let task = Task {
                        for await subject in service.taps {
                            if let uuid = UUID(uuidString: subject) {
                                continuation.yield(Conversation.ID(uuid))
                            }
                        }
                        continuation.finish()
                    }
                    continuation.onTermination = { _ in task.cancel() }
                }
            }
        )
    }
}
