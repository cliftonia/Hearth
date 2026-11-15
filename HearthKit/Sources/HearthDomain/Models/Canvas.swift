import Foundation

/// What a piece of standalone work in a reply is, which decides how the canvas shows it.
public enum CanvasKind: Hashable, Sendable {
    /// A web page, shown as a page.
    case html
    /// A drawing in SVG, shown as a drawing.
    case svg
    /// A document in Markdown, shown laid out.
    case markdown
    /// Code in the language named, if one was; shown as code only.
    case code(language: String?)

    /// Whether the canvas can show the piece as something other than its text.
    public var hasPreview: Bool {
        switch self {
        case .html, .svg, .markdown:
            true
        case .code:
            false
        }
    }
}

/// A piece of standalone work found in a reply: a page, a drawing, a document or a long block of code.
///
/// Nothing of it is stored. It is read out of the reply's text each time it is wanted.
public struct CanvasPiece: Identifiable, Hashable, Sendable {
    /// Its place among the pieces of its reply, counting from zero. A reply is only ever added to at its end
    /// while it streams, so the place of a piece never changes.
    public let index: Int
    public let kind: CanvasKind
    /// The name found for it: a page's own title, a document's first heading or the heading above it in the
    /// reply. `nil` when there is none, and it is then named for its kind.
    public let title: String?
    public let text: String
    public let lineCount: Int
    /// Whether its fence has been closed. One left open is still being written while its reply streams.
    public let isClosed: Bool

    public var id: Int { index }

    public init(index: Int, kind: CanvasKind, title: String?, text: String, lineCount: Int, isClosed: Bool) {
        self.index = index
        self.kind = kind
        self.title = title
        self.text = text
        self.lineCount = lineCount
        self.isClosed = isClosed
    }
}

/// What a stretch of a reply is: ordinary Markdown, or a piece that the canvas can open.
public enum CanvasSegmentKind: Hashable, Sendable {
    case text(String)
    case piece(CanvasPiece)
}

/// One stretch of a reply, identified by its place in the reply.
public struct CanvasSegment: Identifiable, Hashable, Sendable {
    public let id: Int
    public let kind: CanvasSegmentKind

    public init(id: Int, kind: CanvasSegmentKind) {
        self.id = id
        self.kind = kind
    }
}

/// Points at one piece: the reply it is in, and its place among that reply's pieces.
public struct CanvasReference: Hashable, Sendable {
    public let messageID: Message.ID
    public let index: Int

    public init(messageID: Message.ID, index: Int) {
        self.messageID = messageID
        self.index = index
    }
}

/// The pieces of one reply, for telling which pieces of a chat are versions of one another.
public struct CanvasReply: Hashable, Sendable {
    public let messageID: Message.ID
    public let pieces: [CanvasPiece]

    public init(messageID: Message.ID, pieces: [CanvasPiece]) {
        self.messageID = messageID
        self.pieces = pieces
    }
}
