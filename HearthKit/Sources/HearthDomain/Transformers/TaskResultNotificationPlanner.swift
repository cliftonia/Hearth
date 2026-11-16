import Foundation

/// Decides which answers of scheduled tasks are announced, and what each notification says.
///
/// Sync reports a chat the hub filed only when it is new to this device; this decides the rest: the switch must be
/// on, the app not in front of the user, and only a few are announced at once, so a device that was off for a week
/// is not buried in them.
public struct TaskResultNotificationPlanner: Sendable {
    /// The most of an answer that is quoted.
    public static let maximumExcerptLength = 100
    /// The most notifications posted after one sync.
    public static let maximumNotifications = 3

    public init() {}

    /// - Parameters:
    ///   - conversations: The chats filed for a task that sync has just brought in, oldest first.
    ///   - isEnabled: Whether the user has asked to be told of scheduled tasks.
    ///   - isOnScreen: Whether the app is in front of the user, who can then see the new chats for themselves.
    /// - Returns: The notifications to post, newest last; none when nothing should be posted.
    public func notifications(for conversations: [Conversation], isEnabled: Bool, isOnScreen: Bool) -> [ReplyNotification] {
        guard isEnabled, !isOnScreen else {
            return []
        }
        let notices = conversations.compactMap { conversation -> ReplyNotification? in
            guard conversation.taskID != nil, !conversation.isPrivate,
                  let answer = conversation.messages.last(where: { $0.role == .assistant }) else {
                return nil
            }
            let excerpt = Self.excerpt(of: answer.text)
            guard !excerpt.isEmpty else {
                return nil
            }
            return ReplyNotification(conversationID: conversation.id, title: conversation.title, body: excerpt)
        }
        return Array(notices.suffix(Self.maximumNotifications))
    }

    /// The start of an answer on one line, cut at a word where it is too long.
    static func excerpt(of text: String) -> String {
        let line = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard line.count > maximumExcerptLength else {
            return line
        }
        let cut = line.prefix(maximumExcerptLength)
        let whole = cut.lastIndex(of: " ").map { cut[..<$0] } ?? cut
        return whole + "…"
    }
}
