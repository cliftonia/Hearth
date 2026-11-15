import Foundation
import UserNotifications

/// Posts local notifications and reports the ones that are tapped. Nothing is sent to or from a server.
public final class NotificationService: NSObject, Sendable {
    /// Whether the system lets the app post notifications.
    public enum Permission: Sendable {
        /// The user has not been asked yet.
        case notDetermined
        case allowed
        case denied
    }

    /// The key a notification carries the identifier of what it is about under.
    private static let subjectKey = "subject"

    /// The subject of each notification the user taps, in the order they are tapped.
    public let taps: AsyncStream<String>
    private let tapContinuation: AsyncStream<String>.Continuation

    override public init() {
        (taps, tapContinuation) = AsyncStream.makeStream(of: String.self, bufferingPolicy: .bufferingNewest(1))
        super.init()
    }

    /// Begins listening for taps. Called once, as the app starts, so that a tap that opens the app is heard.
    public func activate() {
        UNUserNotificationCenter.current().delegate = self
    }

    public func permission() async -> Permission {
        switch await UNUserNotificationCenter.current().notificationSettings().authorizationStatus {
        case .notDetermined:
            .notDetermined
        case .authorized, .provisional, .ephemeral:
            .allowed
        case .denied:
            .denied
        @unknown default:
            .denied
        }
    }

    /// Asks the user to allow notifications, which the system does only the first time. Returns whether they are allowed.
    public func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// Posts a notification at once. A later one about the same subject takes the place of an earlier one.
    public func post(title: String, body: String, subject: String) async throws {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.threadIdentifier = subject
        content.userInfo = [Self.subjectKey: subject]
        try await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: subject, content: content, trigger: nil))
    }

    /// Takes down everything the app has posted or is about to.
    public func removeAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
}

extension NotificationService: UNUserNotificationCenterDelegate {
    /// A notification that arrives just as the app comes back on screen is still shown, since it was earned off screen.
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    public func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        if let subject = response.notification.request.content.userInfo[Self.subjectKey] as? String {
            tapContinuation.yield(subject)
        }
    }
}
