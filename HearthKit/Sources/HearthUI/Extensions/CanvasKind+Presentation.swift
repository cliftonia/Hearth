import HearthDomain

// How a piece of work is named and drawn, in its card and in the canvas.
extension CanvasKind {
    /// What the kind is called: also the title of a piece that has none of its own.
    var name: String {
        switch self {
        case .html:
            Strings.canvasPage
        case .svg:
            Strings.canvasDrawing
        case .markdown:
            Strings.canvasDocument
        case .code(let language):
            language.map { Strings.canvasCode(language: $0.prefix(1).uppercased() + $0.dropFirst()) } ?? Strings.canvasCode
        }
    }

    var systemImage: String {
        switch self {
        case .html:
            "macwindow"
        case .svg:
            "scribble.variable"
        case .markdown:
            "doc.text"
        case .code:
            "chevron.left.forwardslash.chevron.right"
        }
    }
}

extension CanvasPiece {
    /// The piece's own title, or the name of its kind.
    var displayTitle: String {
        title ?? kind.name
    }

    /// How long it is, in words.
    var lineCountText: String {
        lineCount == 1 ? Strings.canvasOneLine : Strings.canvasLines(number: lineCount)
    }
}
