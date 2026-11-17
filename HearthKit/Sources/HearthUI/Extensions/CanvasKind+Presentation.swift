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

    /// What the canvas's Copy button is called for VoiceOver, so it is not mistaken for a reply's.
    var copyLabel: String {
        switch self {
        case .html:
            Strings.canvasCopyPage
        case .svg:
            Strings.canvasCopyDrawing
        case .markdown:
            Strings.canvasCopyDocument
        case .code:
            Strings.canvasCopyCode
        }
    }

    /// What the canvas's Share button is called for VoiceOver.
    var shareLabel: String {
        switch self {
        case .html:
            Strings.canvasSharePage
        case .svg:
            Strings.canvasShareDrawing
        case .markdown:
            Strings.canvasShareDocument
        case .code:
            Strings.canvasShareCode
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
