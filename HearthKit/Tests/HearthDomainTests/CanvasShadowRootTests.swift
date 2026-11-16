import Foundation
@testable import HearthDomain
import Testing

/// A page's declarative shadow roots, made inert before the canvas loads it.
struct CanvasShadowRootTests {
    @Test(arguments: [
        (
            #"<div><template shadowrootmode="open"><iframe></iframe></template></div>"#,
            #"<div><template data-hearth-shadowrootmode="open"><iframe></iframe></template></div>"#
        ),
        ("<template SHADOWROOTMODE=closed>", "<template data-hearth-SHADOWROOTMODE=closed>"),
        ("<template ShadowRootMode = 'open'>", "<template data-hearth-ShadowRootMode = 'open'>"),
        ("<template shadowroot=open>", "<template data-hearth-shadowroot=open>"),
        (
            "<template\r\nshadowrootmode=open\tshadowrootdelegatesfocus shadowrootclonable/shadowrootserializable>",
            "<template\r\ndata-hearth-shadowrootmode=open\tdata-hearth-shadowrootdelegatesfocus "
                + "data-hearth-shadowrootclonable/data-hearth-shadowrootserializable>"
        ),
        (#"<template a="x"shadowrootmode=open>"#, #"<template a="x"data-hearth-shadowrootmode=open>"#),
        (#"<template title=">" shadowrootmode=open>"#, #"<template title=">" data-hearth-shadowrootmode=open>"#),
        ("<template shadowrootmode", "<template data-hearth-shadowrootmode")
    ])
    func `every attribute that makes a shadow root is renamed, in any case and any form`(markup: String, expected: String) {
        #expect(CanvasShadowRootTransformer.inert(markup) == expected)
    }

    @Test func `a template within a template is reached too`() {
        let markup = #"<div><template shadowrootmode="open"><p><template shadowrootmode="closed"><iframe></iframe></template></p></template></div>"#

        let page = CanvasShadowRootTransformer.inert(markup)

        #expect(page.components(separatedBy: "data-hearth-shadowrootmode").count == 3)
        #expect(page.components(separatedBy: " shadowrootmode").count == 1)
    }

    @Test(arguments: [
        #"<!doctype html><html><body><p class="shadow">Shadows and roots</p><template><b>kept</b></template></body></html>"#,
        #"<div data-shadowrootmode="open" myshadowroot="x" shadowrootmodes="y"></div>"#,
        "<p>The shadowrootmodes; and shadowroot-ish things.</p>",
        #"<svg><circle r="4"/></svg>"#,
        ""
    ])
    func `a page without those attributes is left as it was`(markup: String) {
        #expect(CanvasShadowRootTransformer.inert(markup) == markup)
    }

    @Test func `renaming twice changes nothing more`() {
        let once = CanvasShadowRootTransformer.inert("<template shadowrootmode=open shadowroot>")

        #expect(CanvasShadowRootTransformer.inert(once) == once)
    }

    @Test func `a page and a drawing reach the web view with their shadow roots made inert`() throws {
        let policy = CanvasWebPolicy()
        let page = try #require(policy.document(for: .html, text: #"<div><template shadowrootmode="closed"><iframe></iframe></template></div>"#))
        let drawing = try #require(
            policy.document(for: .svg, text: "<svg><foreignObject><div><template shadowrootmode=open></template></div></foreignObject></svg>")
        )

        #expect(page == #"<div><template data-hearth-shadowrootmode="closed"><iframe></iframe></template></div>"#)
        #expect(drawing.contains("<template data-hearth-shadowrootmode=open>"))
    }

    @Test func `the script makes written markup inert, and sweeps the shadow roots the parser made`() {
        let script = CanvasWebPolicy().startScript

        for name in CanvasShadowRootTransformer.attributeNames {
            #expect(script.contains("'\(name)'"), "\(name)")
        }
        #expect(script.contains("wrap(w, 'Document', 'write', 'value', inertWrite(''))"))
        #expect(script.contains("wrap(w, 'Document', 'writeln', 'value', inertWrite(newline))"))
        #expect(script.contains("'\(CanvasShadowRootTransformer.inertPrefix)'"))
        // Every open shadow root it comes across is kept and watched, and a frame it finds anywhere is sealed.
        #expect(script.contains("getterOf(Element.prototype, 'shadowRoot')"))
        #expect(script.contains("keep(shadow, watchHere)"))
        #expect(script.contains("if (w && !sealed(w)) sweep(w);"))
    }
}
