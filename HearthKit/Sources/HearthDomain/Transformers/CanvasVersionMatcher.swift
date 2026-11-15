import Foundation

/// Tells which pieces of a chat are versions of one piece, so that the canvas can step between them.
///
/// The rule is kept simple. A piece is a version of another when the two are of the same kind and either
/// - they have the same title, or
/// - it is the only piece in its reply, as when a change was asked for and the whole thing was written again.
///
/// Two pieces of code are of the same kind whatever their languages, so code rewritten in another language
/// still counts.
public struct CanvasVersionMatcher: Sendable {
    public init() {}

    /// The versions of a piece, oldest first: every piece in the chat's replies that the rule matches to it,
    /// and the piece itself. Empty when the piece is no longer in the chat.
    public func versions(of anchor: CanvasReference, in replies: [CanvasReply]) -> [CanvasReference] {
        guard let original = replies.first(where: { $0.messageID == anchor.messageID })?.pieces.first(where: { $0.index == anchor.index }) else {
            return []
        }
        return replies.flatMap { reply in
            reply.pieces
                .filter { piece in
                    let reference = CanvasReference(messageID: reply.messageID, index: piece.index)
                    return reference == anchor || isVersion(piece, isAlone: reply.pieces.count == 1, of: original)
                }
                .map { CanvasReference(messageID: reply.messageID, index: $0.index) }
        }
    }

    /// Whether a piece is another version of the original.
    ///
    /// - Parameter isAlone: Whether the piece is the only one in its reply.
    public func isVersion(_ piece: CanvasPiece, isAlone: Bool, of original: CanvasPiece) -> Bool {
        guard Self.family(piece.kind) == Self.family(original.kind) else {
            return false
        }
        return isAlone || Self.hasSameTitle(piece, original)
    }

    /// Titles are compared without regard to case or to the space around them. Two pieces without one do not match.
    private static func hasSameTitle(_ first: CanvasPiece, _ second: CanvasPiece) -> Bool {
        guard let first = first.title, let second = second.title else {
            return false
        }
        let normalise: (String) -> String = { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        return normalise(first) == normalise(second)
    }

    /// The kind with the language of code left out.
    private static func family(_ kind: CanvasKind) -> CanvasKind {
        switch kind {
        case .html, .svg, .markdown:
            kind
        case .code:
            .code(language: nil)
        }
    }
}
