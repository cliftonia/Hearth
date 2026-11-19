import HearthDomain
@testable import HearthUI
import Testing

/// The canvas names its copy and share buttons for what they hold.
@MainActor
struct CanvasLabelTests {
    @Test(arguments: [CanvasKind.html, .svg, .markdown, .code(language: "swift"), .code(language: nil)])
    func `the canvas names its copy and share for what they hold`(kind: CanvasKind) {
        #expect(kind.copyLabel != Strings.copy)
        #expect(kind.shareLabel != Strings.share)
        #expect(kind.copyLabel != kind.shareLabel)
    }

    @Test func `a page and its code are copied under different names`() {
        #expect(CanvasKind.html.copyLabel != CanvasKind.code(language: "html").copyLabel)
    }
}
