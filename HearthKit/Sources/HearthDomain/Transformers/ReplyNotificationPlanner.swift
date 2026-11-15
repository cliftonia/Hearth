import Foundation

/// What a notification about a finished reply says.
public enum ReplyNoticeKind: Hashable, Sendable {
    /// The start of the reply, under the chat's title.
    case text(title: String, excerpt: String)
    /// A picture was made, under the chat's title.
    case picture(title: String)
    /// Only that a reply is ready: a private chat gives away neither its title nor its words.
    case discreet
}

/// Decides whether a finished reply is worth a notification, and what the notification may say.
public struct ReplyNotificationPlanner: Sendable {
    /// The most of a reply that is quoted.
    public static let maximumExcerptLength = 140

    public init() {}

    /// - Parameters:
    ///   - reply: The reply that has just finished.
    ///   - conversation: The chat it is in.
    ///   - isEnabled: Whether the user has asked to be told of replies.
    ///   - isOnScreen: Whether the app is in front of the user at this moment, in which case they can see for themselves.
    /// - Returns: What to say, or `nil` when nothing should be posted.
    public func notice(for reply: Message, in conversation: Conversation, isEnabled: Bool, isOnScreen: Bool) -> ReplyNoticeKind? {
        let hasPicture = !reply.imagesJPEG.isEmpty
        guard isEnabled, !isOnScreen, reply.role == .assistant, hasPicture || !Self.excerpt(of: reply.text).isEmpty else {
            return nil
        }
        if conversation.isPrivate {
            return .discreet
        }
        return hasPicture
            ? .picture(title: conversation.title)
            : .text(title: conversation.title, excerpt: Self.excerpt(of: reply.text))
    }

    /// The start of a reply on one line, cut at a word where it is too long.
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
