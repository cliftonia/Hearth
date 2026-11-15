import Foundation

// The notifications page, the notifications themselves, and the haptics switch.
// swiftlint:disable line_length
extension Strings {
    static let notifications = String(localized: "notifications.title", defaultValue: "Notifications", bundle: .module)
    static let notifyReplies = String(localized: "notifications.replies", defaultValue: "Replies", bundle: .module)
    static let notifyRepliesDetail = String(localized: "notifications.repliesDetail", defaultValue: "When a reply or a picture finishes while Hearth is not on screen.", bundle: .module)
    static let notificationsFooter = String(localized: "notifications.footer", defaultValue: "Notifications are made on this device; nothing is sent through a server. A private chat's notification says only that a reply is ready.", bundle: .module)
    #if targetEnvironment(macCatalyst)
    static let notificationsDenied = String(localized: "notifications.denied.mac", defaultValue: "Notifications are turned off for Hearth in System Settings.", bundle: .module)
    static let notificationsOpenSettings = String(localized: "notifications.openSettings.mac", defaultValue: "Open System Settings", bundle: .module)
    #else
    static let notificationsDenied = String(localized: "notifications.denied", defaultValue: "Notifications are turned off for Hearth in the Settings app.", bundle: .module)
    static let notificationsOpenSettings = String(localized: "notifications.openSettings", defaultValue: "Open the Settings app", bundle: .module)
    #endif
    static let notificationOn = String(localized: "notifications.on", defaultValue: "On", bundle: .module)
    static let notificationOff = String(localized: "notifications.off", defaultValue: "Off", bundle: .module)
    static let notificationReplyReady = String(localized: "notifications.replyReady", defaultValue: "A reply is ready.", bundle: .module)
    static let notificationPictureReady = String(localized: "notifications.pictureReady", defaultValue: "Your picture is ready", bundle: .module)

    static let haptics = String(localized: "haptics.title", defaultValue: "Haptics", bundle: .module)
    static let hapticsFooter = String(localized: "haptics.footer", defaultValue: "A light tap when a message is sent, a reply finishes or something is switched. iPad and Mac have none to give.", bundle: .module)
}
// swiftlint:enable line_length
