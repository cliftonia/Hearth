import Foundation
@testable import HearthDomain
import Testing

/// Which pieces of a chat count as versions of one another, and what a page in the canvas may do.
struct CanvasVersionMatcherTests {
    private static func piece(_ kind: CanvasKind, _ title: String?, index: Int = 0) -> CanvasPiece {
        CanvasPiece(index: index, kind: kind, title: title, text: "", lineCount: 20, isClosed: true)
    }

    @Test(arguments: [
        (CanvasKind.html, "Stopwatch" as String?, CanvasKind.html, "Stopwatch" as String?, false, true),
        (.html, "Stopwatch", .html, " stopwatch ", false, true),
        (.html, "Stopwatch", .html, "Timer", false, false),
        (.html, "Stopwatch", .html, "Timer", true, true),
        (.html, nil, .html, nil, false, false),
        (.html, nil, .html, nil, true, true),
        (.html, "Logo", .svg, "Logo", true, false),
        (.markdown, "Plan", .code(language: "python"), "Plan", true, false),
        (.code(language: "python"), "Sorter", .code(language: "swift"), "Sorter", false, true),
        (.code(language: "python"), nil, .code(language: "swift"), nil, true, true),
        (.code(language: "python"), "Sorter", .code(language: "python"), "Parser", false, false)
    ])
    func `a piece is a version when it is the same kind and has the same title or stands alone`(
        kind: CanvasKind,
        title: String?,
        otherKind: CanvasKind,
        otherTitle: String?,
        isAlone: Bool,
        expected: Bool
    ) {
        let matcher = CanvasVersionMatcher()

        #expect(matcher.isVersion(Self.piece(otherKind, otherTitle), isAlone: isAlone, of: Self.piece(kind, title)) == expected)
    }

    @Test func `the versions of a piece are gathered from the whole chat in order`() {
        let ids = (0..<4).map { _ in Message.ID(UUID()) }
        let replies = [
            CanvasReply(messageID: ids[0], pieces: [Self.piece(.html, "Stopwatch")]),
            CanvasReply(messageID: ids[1], pieces: []),
            CanvasReply(messageID: ids[2], pieces: [Self.piece(.code(language: "css"), "Styles"), Self.piece(.html, "Stopwatch", index: 1)]),
            CanvasReply(messageID: ids[3], pieces: [Self.piece(.html, "Stopwatch with laps")])
        ]
        let expected = [
            CanvasReference(messageID: ids[0], index: 0),
            CanvasReference(messageID: ids[2], index: 1),
            CanvasReference(messageID: ids[3], index: 0)
        ]

        for anchor in [expected[0], expected[1]] {
            #expect(CanvasVersionMatcher().versions(of: anchor, in: replies) == expected)
        }
        #expect(CanvasVersionMatcher().versions(of: CanvasReference(messageID: ids[2], index: 0), in: replies).count == 1)
    }

    @Test func `a piece that is no longer in the chat has no versions`() {
        let replies = [CanvasReply(messageID: Message.ID(UUID()), pieces: [Self.piece(.html, "Stopwatch")])]

        #expect(CanvasVersionMatcher().versions(of: CanvasReference(messageID: Message.ID(UUID()), index: 0), in: replies).isEmpty)
        #expect(CanvasVersionMatcher().versions(of: CanvasReference(messageID: replies[0].messageID, index: 3), in: replies).isEmpty)
    }
}

/// What a page shown in the canvas may load and where it may go.
struct CanvasWebPolicyTests {
    @Test(arguments: ["about:blank", "about:blank#section", "about:srcdoc", "ABOUT:blank"])
    func `the page itself and places within it may be loaded`(address: String) {
        #expect(CanvasWebPolicy().decision(forNavigationTo: URL(string: address)) == .allow)
    }

    @Test(arguments: [
        "https://example.com/",
        "http://example.com/?secret=1",
        "HTTPS://EXAMPLE.COM",
        "file:///etc/hosts",
        "data:text/html,<p>hi</p>",
        "blob:null/1234",
        "javascript:alert(1)",
        "hearth://voice",
        "tel:123",
        "mailto:someone@example.com",
        "x-web-search://?query",
        "ws://example.com/socket"
    ])
    func `every way out of the page is cancelled`(address: String) {
        #expect(CanvasWebPolicy().decision(forNavigationTo: URL(string: address)) == .cancel)
    }

    @Test func `a navigation with no address is cancelled`() {
        #expect(CanvasWebPolicy().decision(forNavigationTo: nil) == .cancel)
    }

    @Test(arguments: [
        "http://example.com/a.png",
        "https://example.com/api?q=1",
        "HTTPS://EXAMPLE.COM/",
        "ws://example.com/socket",
        "wss://example.com/socket",
        "ftp://example.com/file"
    ])
    func `the content rules block every address that reaches the network`(address: String) throws {
        let rules = try Self.rules()

        // A content blocker's filters are matched without regard to case, as here.
        let isBlocked = try rules.contains { rule in
            let filter = try #require((rule["trigger"] as? [String: String])?["url-filter"])
            let expression = try NSRegularExpression(pattern: filter, options: .caseInsensitive)
            return expression.firstMatch(in: address, range: NSRange(address.startIndex..., in: address)) != nil
        }

        #expect(isBlocked)
    }

    @Test func `every content rule blocks, for every kind of load and every frame`() throws {
        for rule in try Self.rules() {
            #expect((rule["action"] as? [String: String]) == ["type": "block"])
            #expect((rule["trigger"] as? [String: String])?.keys.sorted() == ["url-filter"])
        }
    }

    @Test func `no window, camera, microphone or sensor is granted`() {
        #expect(!CanvasWebPolicy.allowsNewWindows)
        #expect(!CanvasWebPolicy.allowsMediaCapture)
        #expect(!CanvasWebPolicy.allowsMotionSensors)
    }

    @Test func `a page is loaded as written and a drawing inside a page of its own`() throws {
        let policy = CanvasWebPolicy()
        let drawing = try #require(policy.document(for: .svg, text: "<svg id=\"mark\"></svg>"))

        #expect(policy.document(for: .html, text: "<p>Hi</p>") == "<p>Hi</p>")
        #expect(drawing.hasPrefix("<!doctype html>"))
        #expect(drawing.contains("<svg id=\"mark\"></svg>"))
        #expect(policy.document(for: .markdown, text: "# Hi") == nil)
        #expect(policy.document(for: .code(language: "swift"), text: "let x = 1") == nil)
    }

    private static func rules() throws -> [[String: Any]] {
        let data = Data(CanvasWebPolicy().contentRules.utf8)
        return try #require(try JSONSerialization.jsonObject(with: data) as? [[String: Any]])
    }
}
