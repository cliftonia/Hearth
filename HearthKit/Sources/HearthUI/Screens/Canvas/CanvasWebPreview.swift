import HearthCore
import HearthDomain
import os
import SwiftUI
import WebKit

/// A page or a drawing written by a model, shown in a web view that can reach nothing outside itself.
///
/// What it may do is decided by `CanvasWebPolicy`; this view carries the decisions out:
/// - the page is loaded from a string with no address, into a store that keeps nothing;
/// - no web view is made until the rules that block every network request are compiled and installed, and if
///   they cannot be, nothing is loaded and `isUnavailable` is set;
/// - every navigation away from the page is cancelled, so a link opens nothing;
/// - new windows, the camera, the microphone, the motion sensors and link menus are refused.
struct CanvasWebPreview: UIViewRepresentable {
    /// The document to show. `nil` leaves whatever is showing, as while a newer version is still being written.
    let document: String?
    /// Set when the page could not be shut off from the network and so was not loaded.
    @Binding var isUnavailable: Bool

    func makeCoordinator() -> CanvasWebGuard {
        CanvasWebGuard()
    }

    func makeUIView(context: Context) -> UIView {
        UIView()
    }

    func updateUIView(_ container: UIView, context: Context) {
        guard let document, document != context.coordinator.shownDocument else {
            return
        }
        context.coordinator.shownDocument = document
        let isUnavailable = $isUnavailable
        Task {
            let isShown = await context.coordinator.show(document, in: container)
            isUnavailable.wrappedValue = !isShown
        }
    }
}

/// Holds the web view of a `CanvasWebPreview` and answers everything it asks with the policy's decisions.
@MainActor
final class CanvasWebGuard: NSObject {
    /// The document most lately asked for, which is the one that ends up showing.
    var shownDocument: String?

    private let policy = CanvasWebPolicy()
    private let logger = Logger(for: CanvasWebGuard.self)
    private var webView: WKWebView?
    /// The compiled rules, shared by every canvas for as long as the app runs.
    private static var contentRules: WKContentRuleList?

    /// Loads the document, making the web view first if there is none. Returns whether it could be shown.
    func show(_ document: String, in container: UIView) async -> Bool {
        guard let webView = await preparedWebView(in: container) else {
            return false
        }
        // Another document may have been asked for while the rules were compiled; the latest is the one to show.
        if document == shownDocument {
            webView.loadHTMLString(document, baseURL: nil)
        }
        return true
    }

    /// The web view, made once the rules that block the network are in hand; `nil` if they cannot be had.
    private func preparedWebView(in container: UIView) async -> WKWebView? {
        if let webView {
            return webView
        }
        guard let rules = await compiledRules() else {
            return nil
        }
        // Two documents asked for at once both wait for the rules; the second finds the first's web view.
        if let webView {
            return webView
        }
        let webView = WKWebView(frame: container.bounds, configuration: configuration(rules: rules))
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsLinkPreview = false
        webView.allowsBackForwardNavigationGestures = false
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.addSubview(webView)
        self.webView = webView
        return webView
    }

    private func configuration(rules: WKContentRuleList) -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = CanvasWebPolicy.allowsNewWindows
        configuration.mediaTypesRequiringUserActionForPlayback = .all
        configuration.allowsAirPlayForMediaPlayback = false
        configuration.allowsPictureInPictureMediaPlayback = false
        configuration.dataDetectorTypes = []
        configuration.userContentController.add(rules)
        configuration.userContentController.addUserScript(
            WKUserScript(source: policy.startScript, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        )
        return configuration
    }

    private func compiledRules() async -> WKContentRuleList? {
        if let rules = Self.contentRules {
            return rules
        }
        do {
            let rules = try await WKContentRuleListStore.default().compileContentRuleList(
                forIdentifier: CanvasWebPolicy.contentRulesIdentifier,
                encodedContentRuleList: policy.contentRules
            )
            Self.contentRules = rules
            return rules
        } catch {
            logger.error("Compiling the canvas's network rules failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}

// MARK: - WKNavigationDelegate

extension CanvasWebGuard: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        switch policy.decision(forNavigationTo: navigationAction.request.url) {
        case .allow:
            return .allow
        case .cancel:
            // The address is part of a reply, so it is not logged.
            logger.info("The canvas cancelled a navigation away from its page")
            return .cancel
        }
    }
}

// MARK: - WKUIDelegate

extension CanvasWebGuard: WKUIDelegate {
    /// `window.open` and links with a target get no window.
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        nil
    }

    func webView(
        _ webView: WKWebView,
        decideMediaCapturePermissionsFor origin: WKSecurityOrigin,
        initiatedBy frame: WKFrameInfo,
        type: WKMediaCaptureType
    ) async -> WKPermissionDecision {
        CanvasWebPolicy.allowsMediaCapture ? .grant : .deny
    }

    func webView(
        _ webView: WKWebView,
        requestDeviceOrientationAndMotionPermissionFor origin: WKSecurityOrigin,
        initiatedByFrame frame: WKFrameInfo
    ) async -> WKPermissionDecision {
        CanvasWebPolicy.allowsMotionSensors ? .grant : .deny
    }

    /// A long press on a link offers nothing, since the menu's own choices would open or copy the link.
    func webView(_ webView: WKWebView, contextMenuConfigurationFor elementInfo: WKContextMenuElementInfo) async -> UIContextMenuConfiguration? {
        nil
    }
}
