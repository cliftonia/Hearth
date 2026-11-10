import Foundation

/// How a reply will reach the user, which changes how it should be written.
public enum ReplyStyle: Sendable {
    case chat
    case voice
}

/// Turns a conversation, and any web results, into the messages sent to the model.
public struct PromptBuilder: Sendable {
    public init() {}

    public func messages(history: [Message], sources: [SearchSource], style: ReplyStyle, now: Date) -> [PromptMessage] {
        let system = PromptMessage(role: .system, text: systemText(sources: sources, style: style, now: now))
        let turns = history
            .filter { !$0.text.isEmpty || !$0.imagesJPEG.isEmpty }
            .map { message in
                PromptMessage(
                    role: message.role == .user ? .user : .assistant,
                    text: message.text,
                    imagesJPEG: message.imagesJPEG
                )
            }
        return [system] + turns
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
