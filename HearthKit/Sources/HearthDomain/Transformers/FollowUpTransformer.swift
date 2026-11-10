import Foundation

/// Asks a model for questions the user might put next, and reads them out of its answer.
public struct FollowUpTransformer: Sendable {
    public static let maximumCount = 3
    private static let excerptLength = 1500

    public init() {}

    /// The request sent to the model, built from the latest question and reply. `nil` when there is no exchange yet.
    public func prompt(history: [Message]) -> String? {
        guard let reply = history.last(where: { $0.role == .assistant && !$0.text.isEmpty }),
              let question = history.last(where: { $0.role == .user }) else {
            return nil
        }
        return """
        Here is the latest exchange of a conversation.

        User: \(question.text.prefix(Self.excerptLength))

        Assistant: \(reply.text.prefix(Self.excerptLength))

        Suggest \(Self.maximumCount) short follow-up questions the user might ask next. Write each on its own line, \
        worded as the user would ask it, in the user's language. No numbering, no quotes and no other text.
        """
    }

    /// The questions in a model's answer: one per line, without list markers or quotes, and never more than three.
    public func questions(from answer: String) -> [String] {
        let questions = answer
            .split(whereSeparator: \.isNewline)
            .map { line in
                String(line).trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: #"^([-*•]|\d+[.)])\s*"#, with: "", options: .regularExpression)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'“”‘’*_ "))
            }
            .filter { (8...140).contains($0.count) && $0.hasSuffix("?") }
        return Array(questions.prefix(Self.maximumCount))
    }
}
