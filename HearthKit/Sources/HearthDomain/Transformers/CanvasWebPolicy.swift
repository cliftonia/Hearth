import Foundation

/// What the canvas decides about a navigation its page asks for.
public enum CanvasNavigationDecisionKind: Hashable, Sendable {
    case allow
    case cancel
}

/// What a page shown in the canvas may do. The page was written by a model, so it is untrusted: it may run its
/// own scripts, and nothing else.
///
/// - It is loaded from a string with no address of its own, so it has no origin and no files to reach.
/// - Nothing is fetched over the network: `contentRules` blocks every request a page can make.
/// - It goes nowhere: `decision(forNavigationTo:)` cancels every navigation but the page's own loading. A tapped
///   link therefore opens nothing, here or in the browser.
/// - It is given no window, camera, microphone or motion sensor: the three constants below.
/// - It is given no peer connection, in its own window or any frame's, and no frame it cannot reach:
///   `startScript`, and no shadow root made from its markup, where a frame could be hidden from that script:
///   `document(for:text:)`.
///
/// The web view that enforces this is `CanvasWebPreview`; the decisions are here so that they can be tested.
public struct CanvasWebPolicy: Sendable {
    /// The schemes a page could reach the network through. Every request to one is blocked.
    public static let blockedSchemePatterns = ["^https?://", "^wss?://", "^ftp://"]
    /// A page that asks for a new window, as `window.open` and a link with a target do, gets none.
    public static let allowsNewWindows = false
    /// A page that asks for the camera or the microphone is refused without the user being asked.
    public static let allowsMediaCapture = false
    /// A page that asks for the motion sensors is refused without the user being asked.
    public static let allowsMotionSensors = false
    /// The name the compiled rules are kept under. It changes whenever the rules do.
    public static let contentRulesIdentifier = "canvas-block-network-1"

    public init() {}

    /// The rules handed to the web view's content blocker, as the JSON it reads: one rule for each scheme that
    /// reaches the network, blocking every kind of load, from every frame.
    public var contentRules: String {
        let rules = Self.blockedSchemePatterns.map { pattern in
            ["trigger": ["url-filter": pattern], "action": ["type": "block"]]
        }
        guard let data = try? JSONSerialization.data(withJSONObject: rules, options: [.sortedKeys]) else {
            return "[]"
        }
        return String(bytes: data, encoding: .utf8) ?? "[]"
    }

    /// Whether a navigation may go ahead. A page loaded from a string lives at `about:blank`, and so do the
    /// frames it writes itself and the places within it that its own links jump to. Those are allowed; anything
    /// with any other address is a way out of the page and is cancelled, whether a tap or a script asked for it.
    public func decision(forNavigationTo url: URL?) -> CanvasNavigationDecisionKind {
        url?.scheme?.lowercased() == "about" ? .allow : .cancel
    }

    /// The document the web view is given for a piece: a page as it was written, a drawing centred in a page of
    /// its own, each with its declarative shadow roots made inert (`CanvasShadowRootTransformer`). `nil` for a kind
    /// that is not shown in a web view.
    public func document(for kind: CanvasKind, text: String) -> String? {
        switch kind {
        case .html:
            CanvasShadowRootTransformer.inert(text)
        case .svg:
            """
            <!doctype html>
            <html>
            <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style>
            html, body { height: 100%; margin: 0; background: #ffffff; }
            body { display: flex; align-items: center; justify-content: center; }
            svg { max-width: 100%; max-height: 100%; }
            </style>
            </head>
            <body>
            \(CanvasShadowRootTransformer.inert(text))
            </body>
            </html>
            """
        case .markdown, .code:
            nil
        }
    }
}
