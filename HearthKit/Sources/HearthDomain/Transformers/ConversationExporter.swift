import Foundation

/// Writes a conversation out as Markdown, ready to share.
public struct ConversationExporter: Sendable {
    private let userLabel: String
    private let assistantLabel: String
    private let untitled: String

    /// - Parameters:
    ///   - userLabel: The heading over each of the user's messages.
    ///   - assistantLabel: The heading over each reply.
    ///   - untitled: The title used when the conversation has none.
    public init(userLabel: String, assistantLabel: String, untitled: String) {
        self.userLabel = userLabel
        self.assistantLabel = assistantLabel
        self.untitled = untitled
    }

    public func markdown(for conversation: Conversation) -> String {
        let title = "# " + (conversation.title.isEmpty ? untitled : conversation.title)
        let turns = conversation.messages.filter { !$0.isEmpty }.map { message in
            let label = message.role == .user ? userLabel : assistantLabel
            let files = message.documents.map { "_\($0.name)_" }
            let sources = message.sources.enumerated().map { "\($0.offset + 1). [\($0.element.title)](\($0.element.url.absoluteString))" }
            return (["**\(label)**"] + files + [message.text] + sources).filter { !$0.isEmpty }.joined(separator: "\n\n")
        }
        return ([title] + turns).joined(separator: "\n\n") + "\n"
    }
}
