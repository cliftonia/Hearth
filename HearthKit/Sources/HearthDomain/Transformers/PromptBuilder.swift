import Foundation

/// How a reply will reach the user, which changes how it should be written.
public enum ReplyStyle: Sendable {
    case chat
    case voice
}

/// Turns a conversation, and any web results, into the messages sent to the model.
public struct PromptBuilder: Sendable {
    /// The most text taken from one attached file, so a long document cannot crowd out the conversation.
    public static let maximumDocumentLength = 60_000

    private let instructions: String

    /// - Parameter instructions: The user's standing instructions, if any.
    public init(instructions: String) {
        self.instructions = instructions.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// - Parameter offersSearch: Whether the model is being given a web search tool to call when it needs one.
    public func messages(history: [Message], sources: [SearchSource], style: ReplyStyle, now: Date, offersSearch: Bool = false) -> [PromptMessage] {
        var systemText = systemText(sources: sources, style: style, now: now)
        if offersSearch {
            systemText += "\n\nYou can search the web with the web_search tool. Use it when a question needs current "
                + "information or facts you are not sure of. Answer directly, without searching, when you already know."
        }
        let system = PromptMessage(role: .system, text: systemText)
        let turns = history
            .filter { !$0.isEmpty }
            .map { message in
                PromptMessage(
                    role: message.role == .user ? .user : .assistant,
                    text: text(of: message),
                    imagesJPEG: message.imagesJPEG
                )
            }
        return [system] + turns
    }

    /// The message as the model reads it: any attached files first, then what was typed.
    private func text(of message: Message) -> String {
        let files = message.documents.map { document in
            "Attached file \"\(document.name)\":\n\(document.text.prefix(Self.maximumDocumentLength))"
        }
        return (files + [message.text]).filter { !$0.isEmpty }.joined(separator: "\n\n")
    }

    /// Search results as the model reads them after asking for a search, numbered so that it can cite them.
    public func searchResultsText(_ sources: [SearchSource], numberedFrom first: Int) -> String {
        guard !sources.isEmpty else {
            return "The search returned no results. Say so if you cannot answer without them."
        }
        let listing = sources.enumerated()
            .map { index, source in "[\(first + index)] \(source.title)\n\(source.url.absoluteString)\n\(source.snippet)" }
            .joined(separator: "\n\n")
        return "\(listing)\n\nCite the results you use as [1], [2]. Say so if they do not answer the question."
    }

    /// The text to search the web for: the user's latest message, kept to a searchable length.
    public func searchQuery(history: [Message]) -> String? {
        guard let text = history.last(where: { $0.role == .user })?.text else {
            return nil
        }
        let query = text.split(whereSeparator: \.isNewline).joined(separator: " ").prefix(200)
        return query.isEmpty ? nil : String(query)
    }

    private func systemText(sources: [SearchSource], style: ReplyStyle, now: Date) -> String {
        var parts = ["You are a helpful, direct assistant. Today is \(now.formatted(date: .complete, time: .omitted))."]
        switch style {
        case .chat:
            parts.append("Format replies in Markdown when it helps the reader.")
        case .voice:
            parts.append(
                "Your reply will be spoken aloud. Answer in a few short, natural sentences. "
                    + "Use no Markdown, lists, code or symbols."
            )
        }
        if !instructions.isEmpty {
            parts.append("The user has given these standing instructions. Follow them:\n\(instructions)")
        }
        if !sources.isEmpty {
            let listing = sources.enumerated()
                .map { index, source in "[\(index + 1)] \(source.title)\n\(source.url.absoluteString)\n\(source.snippet)" }
                .joined(separator: "\n\n")
            parts.append(
                "Web search results for the user's latest message follow. Use them when relevant, "
                    + "cite them as [1], [2], and say so if they do not answer the question.\n\n\(listing)"
            )
        }
        return parts.joined(separator: "\n\n")
    }
}
