import Foundation
@testable import HearthDomain
import Testing

/// Which parts of a reply are pieces of standalone work, what kind each is and what it is called.
struct CanvasExtractorTests {
    /// A fenced block of the given number of numbered lines.
    private static func block(_ language: String, lines: Int, fence: String = "```") -> String {
        ([fence + language] + (1...lines).map { "line \($0)" } + [fence]).joined(separator: "\n")
    }

    private func pieces(_ markdown: String) -> [CanvasPiece] {
        CanvasExtractor().pieces(from: markdown)
    }

    // MARK: Kinds

    @Test(arguments: [
        ("```html\n<p>Hello</p>\n```", CanvasKind.html),
        ("```HTML\n<p>Hello</p>\n```", .html),
        ("```\n<!DOCTYPE html>\n<html></html>\n```", .html),
        ("```xml\n  <html lang=\"en\"></html>\n```", .html),
        ("```svg\n<circle r=\"4\"/>\n```", .svg),
        ("```\n<svg viewBox=\"0 0 10 10\"></svg>\n```", .svg),
        ("```xml\n<?xml version=\"1.0\"?>\n<svg></svg>\n```", .svg),
        (block("markdown", lines: 15), .markdown),
        (block("md", lines: 20), .markdown),
        (block("python", lines: 15), .code(language: "python")),
        (block("", lines: 15), .code(language: nil))
    ])
    func `a block is a piece of the kind its language or its opening says`(markdown: String, kind: CanvasKind) {
        #expect(pieces(markdown).map(\.kind) == [kind])
    }

    @Test(arguments: [
        block("python", lines: 14),
        block("markdown", lines: 14),
        block("", lines: 3),
        "```xml\n<note>not a page</note>\n```",
        "```html\n```",
        "Some `inline` code and ```more inline``` on a line.",
        "No code at all."
    ])
    func `a short block that is neither a page nor a drawing stays in the reply`(markdown: String) {
        let segments = CanvasExtractor().segments(from: markdown)

        #expect(segments.map(\.kind) == [.text(markdown)])
    }

    @Test(arguments: [(14, 0), (15, 1), (40, 1)])
    func `code becomes a piece at fifteen lines`(lines: Int, pieceCount: Int) {
        #expect(pieces(Self.block("swift", lines: lines)).count == pieceCount)
    }

    @Test func `blank lines at the end of a block are not counted`() {
        let markdown = "```python\n" + (1...14).map { "line \($0)" }.joined(separator: "\n") + "\n\n\n```"

        #expect(pieces(markdown).isEmpty)
    }

    // MARK: Segments

    @Test func `a reply is cut into its words and its pieces in order`() {
        let page = "```html\n<p>One</p>\n```"
        let short = "```sh\nls\n```"
        let markdown = "Here it is:\n\(page)\nRun it with:\n\(short)\nThen the long one:\n\(Self.block("python", lines: 16))\nDone."

        let segments = CanvasExtractor().segments(from: markdown)

        #expect(segments.map(\.id) == [0, 1, 2, 3, 4])
        #expect(segments[0].kind == .text("Here it is:"))
        #expect(segments[2].kind == .text("Run it with:\n\(short)\nThen the long one:"))
        #expect(segments[4].kind == .text("Done."))
        #expect(pieces(markdown).map(\.index) == [0, 1])
        #expect(pieces(markdown).map(\.kind) == [.html, .code(language: "python")])
        #expect(pieces(markdown)[0].text == "<p>One</p>")
        #expect(pieces(markdown)[0].lineCount == 1)
    }

    // MARK: Streaming

    @Test(arguments: [
        ("Here:\n```html", 0),
        ("Here:\n```html\n<!doctype html>", 1),
        ("Here:\n```html\n<!doctype html>\n<p>Hi", 2)
    ])
    func `a page whose fence is still open is a piece being written`(markdown: String, lineCount: Int) throws {
        let piece = try #require(pieces(markdown).first)

        #expect(piece.kind == .html)
        #expect(!piece.isClosed)
        #expect(piece.lineCount == lineCount)
    }

    @Test func `code still open becomes a piece once it is long enough and keeps its place`() {
        let first = "```html\n<p>One</p>\n```\n"
        let open14 = first + "```python\n" + (1...14).map { "line \($0)" }.joined(separator: "\n")
        let open15 = open14 + "\nline 15"

        #expect(pieces(open14).map(\.index) == [0])
        #expect(pieces(open15).map(\.index) == [0, 1])
        #expect(pieces(open15).map(\.isClosed) == [true, false])
        #expect(pieces(open15 + "\n```").map(\.isClosed) == [true, true])
    }

    // MARK: Fences within fences

    @Test func `a longer fence holds shorter ones as its text`() throws {
        let inner = "```js\nconsole.log(1)\n```"
        let markdown = "````html\n<pre>\n\(inner)\n</pre>\n````\nAfter."

        let piece = try #require(pieces(markdown).first)

        #expect(piece.text == "<pre>\n\(inner)\n</pre>")
        #expect(piece.isClosed)
        #expect(CanvasExtractor().segments(from: markdown).last?.kind == .text("After."))
    }

    @Test func `a document keeps the fenced blocks written inside it behind fences like its own`() throws {
        let lines = ["# Guide"] + (1...12).map { "Step \($0)" } + ["```sh", "make", "```", "The end."]
        let markdown = "```markdown\n" + lines.joined(separator: "\n") + "\n```\nAfter."

        let piece = try #require(pieces(markdown).first)

        #expect(piece.kind == .markdown)
        #expect(piece.lineCount == lines.count)
        #expect(piece.text.hasSuffix("The end."))
        #expect(CanvasExtractor().segments(from: markdown).last?.kind == .text("After."))
    }

    @Test func `code is closed by the first bare fence whatever follows a language-marked line inside it`() throws {
        let markdown = Self.block("python", lines: 15) + "\n```sh\nls\n```"

        #expect(pieces(markdown).count == 1)
        #expect(try #require(pieces(markdown).first).lineCount == 15)
    }

    // MARK: Titles

    @Test(arguments: [
        ("```html\n<html><head><title>Stop &amp; Go</title></head></html>\n```", "Stop & Go"),
        ("```html\n<TITLE>\n  Two\n  lines </TITLE>\n```", "Two lines"),
        ("## A **bold** `plan`:\n\nHere:\n```html\n<p>Hi</p>\n```", "A bold plan"),
        ("# Far heading\n```sh\nls\n```\n### Near heading ###\n```svg\n<svg></svg>\n```", "Near heading"),
        ("# Above\n```html\n<title>Inside</title>\n```", "Inside"),
        ("# Above\n```markdown\n" + (["Intro", "## Within"] + (1...14).map { "Line \($0)" }).joined(separator: "\n") + "\n```", "Within")
    ])
    func `a piece is named by itself first and then by the heading above it`(markdown: String, title: String) {
        #expect(pieces(markdown).last?.title == title)
    }

    @Test(arguments: [
        "```html\n<p>No title</p>\n```",
        "```html\n<title>   </title>\n```",
        "# Used up\n```sh\nls\n```\n```html\n<p>Hi</p>\n```",
        "# Too far\n" + (1...13).map { "Line \($0)" }.joined(separator: "\n") + "\n```html\n<p>Hi</p>\n```",
        "#NotAHeading\n```html\n<p>Hi</p>\n```"
    ])
    func `a piece with no name of its own and no heading near it has no title`(markdown: String) {
        #expect(pieces(markdown).last?.title == nil)
    }

    @Test func `a very long title is cut short`() {
        let markdown = "```html\n<title>" + String(repeating: "word ", count: 60) + "</title>\n```"

        #expect(pieces(markdown).first?.title?.count == CanvasExtractor.maximumTitleLength)
    }
}
