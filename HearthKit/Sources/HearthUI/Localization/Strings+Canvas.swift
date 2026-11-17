import Foundation

// The canvas: the card a piece of work has in a reply, and the panel it opens in.
// swiftlint:disable line_length
extension Strings {
    static let canvas = String(localized: "canvas.title", defaultValue: "Canvas", bundle: .module)
    static let canvasOpen = String(localized: "canvas.open", defaultValue: "Open", bundle: .module)
    static let canvasWriting = String(localized: "canvas.writing", defaultValue: "Writing…", bundle: .module)
    static let canvasPage = String(localized: "canvas.kind.page", defaultValue: "Page", bundle: .module)
    static let canvasDrawing = String(localized: "canvas.kind.drawing", defaultValue: "Drawing", bundle: .module)
    static let canvasDocument = String(localized: "canvas.kind.document", defaultValue: "Document", bundle: .module)
    static let canvasCode = String(localized: "canvas.kind.code", defaultValue: "Code", bundle: .module)
    static let canvasOneLine = String(localized: "canvas.oneLine", defaultValue: "1 line", bundle: .module)
    static let canvasPreview = String(localized: "canvas.preview", defaultValue: "Preview", bundle: .module)
    static let canvasShowAs = String(localized: "canvas.showAs", defaultValue: "Show as", bundle: .module)
    static let canvasClose = String(localized: "canvas.close", defaultValue: "Close canvas", bundle: .module)
    static let canvasEarlier = String(localized: "canvas.earlier", defaultValue: "Earlier version", bundle: .module)
    static let canvasLater = String(localized: "canvas.later", defaultValue: "Later version", bundle: .module)
    static let canvasPreviewUnavailable = String(localized: "canvas.previewUnavailable", defaultValue: "The preview could not be shut off from the network, so it is not shown. The code is still here.", bundle: .module)

    static func canvasCode(language: String) -> String {
        String(localized: "canvas.kind.codeIn", defaultValue: "\(language) code", bundle: .module)
    }

    static func canvasLines(number: Int) -> String {
        String(localized: "canvas.lines", defaultValue: "\(number) lines", bundle: .module)
    }

    static func canvasVersion(number: Int, total: Int) -> String {
        String(localized: "canvas.version", defaultValue: "\(number) of \(total)", bundle: .module)
    }

    static func canvasOpenLabel(title: String, detail: String) -> String {
        String(localized: "canvas.openLabel", defaultValue: "\(title), \(detail). Open in the canvas", bundle: .module)
    }

    static func canvasWritingLabel(title: String) -> String {
        String(localized: "canvas.writingLabel", defaultValue: "\(title), being written. Open in the canvas", bundle: .module)
    }
}
// swiftlint:enable line_length
