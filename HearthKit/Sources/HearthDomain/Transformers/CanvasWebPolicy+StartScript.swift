import Foundation

public extension CanvasWebPolicy {
    /// Run before the page's own scripts, in the page and in every frame where the web view can: takes away the one
    /// way to reach the network that is not a request and so is not covered by the content rules, a peer connection.
    ///
    /// Taking them out of the page's own window is not enough. The web view runs the script at the start of most
    /// frames' documents, but not in the empty document a frame holds while it waits for its own to load (a
    /// `srcdoc`, an address that is blocked or a `javascript:` address), and the page can take a peer connection
    /// from there at once (measured on the simulator). So the script does the same to every frame the moment it is
    /// made or reached, before the page can use it: everything a script makes a frame or reaches its window with
    /// (putting elements or markup into the page, `document.write`, a frame's `contentWindow`, and the like) seals
    /// every frame in the page as it does so, frames within frames included, and puts the same script into each. A
    /// frame that the parser puts in the page is sealed before the next script runs, by a watch on the document's
    /// changes, and one whose loading runs the page's code at once, by listening ahead of the page.
    ///
    /// It fails closed. A frame it cannot reach cannot be sealed, and the only frame in a page that cannot be
    /// reached is one with a `sandbox` that keeps it apart, so a sandbox is never given: it is taken off a frame
    /// before the frame is put in the page, and setting one is ignored. A frame it still cannot reach is taken
    /// out of the page. Markup that would make a shadow root is read as plain markup, so a frame cannot be hidden
    /// in one. What it uses it takes before the page can change it.
    ///
    /// The Android app's script does three things more, each for a reason that does not hold in WebKit, so they are
    /// left out here on purpose:
    /// - It has `navigator.sendBeacon` answer that nothing was sent. A beacon is a load like any other to the content
    ///   rules, which block it here, so nothing leaves either way; all that is left is a beacon answering that it
    ///   was sent when it was then blocked, which tells the page nothing it could use to get out.
    /// - It replaces `Document.parseHTMLUnsafe` only where the engine has it. Here it is put in place always, fixed,
    ///   so that where WebKit lacks it a page cannot put in one of its own either; the stricter of the two.
    /// - It wraps `DOMParser.parseFromString` so that a parser is never asked to `includeShadowRoots`, a Chromium
    ///   option. WebKit's parser takes no such option and never makes a shadow root from markup.
    var startScript: String {
        """
        (function () {
            'use strict';
            // Taken before the page can change them, so that nothing the page does later reaches into what follows.
            var call = Reflect.apply, describe = Object.getOwnPropertyDescriptor, define = Object.defineProperty;
            var toText = String, lower = String.prototype.toLowerCase, lastIndexOf = String.prototype.lastIndexOf;
            var cut = String.prototype.slice, copy = Array.prototype.slice;
            function getterOf(proto, name) { var held = describe(proto, name); return held && held.get; }
            function setterOf(proto, name) { var held = describe(proto, name); return held && held.set; }
            var lengthOf = getterOf(window, 'length') || getterOf(Window.prototype, 'length');
            var countOf = getterOf(NodeList.prototype, 'length'), typeOf = getterOf(Node.prototype, 'nodeType');
            var tagOf = getterOf(Element.prototype, 'localName'), attributeNameOf = getterOf(Attr.prototype, 'localName');
            var markupInto = setterOf(Element.prototype, 'innerHTML'), markupIntoShadow = setterOf(ShadowRoot.prototype, 'innerHTML');
            var hasAttribute = Element.prototype.hasAttribute, removeAttribute = Element.prototype.removeAttribute;
            var removeNode = Element.prototype.remove, makeElement = Document.prototype.createElement;
            var Parser = DOMParser, parse = DOMParser.prototype.parseFromString;
            var iframeWindow = getterOf(HTMLIFrameElement.prototype, 'contentWindow');
            var frameWindow = getterOf(HTMLFrameElement.prototype, 'contentWindow');
            var objectWindow = getterOf(HTMLObjectElement.prototype, 'contentWindow');
            var findAll = {
                1: Element.prototype.querySelectorAll,
                9: Document.prototype.querySelectorAll,
                11: DocumentFragment.prototype.querySelectorAll
            };
            var root = window.top, roots = [];
            var FRAMES = 'iframe, frame, object, [sandbox]';
            var NAMES = ['RTCPeerConnection', 'webkitRTCPeerConnection', 'RTCDataChannel', 'RTCIceCandidate', 'RTCSessionDescription'];
            var EVENTS = ['load', 'error', 'readystatechange', 'DOMContentLoaded', 'focus', 'focusin', 'toggle', 'slotchange'];
            // Each way a script reaches a frame's window, or puts a frame in the page.
            var GETTERS = [
                ['HTMLIFrameElement', ['contentWindow', 'contentDocument']],
                ['HTMLFrameElement', ['contentWindow', 'contentDocument']],
                ['HTMLObjectElement', ['contentWindow', 'contentDocument']]
            ];
            var METHODS = [
                ['Node', ['appendChild', 'insertBefore', 'replaceChild']],
                ['Element', ['append', 'prepend', 'before', 'after', 'replaceWith', 'replaceChildren']],
                ['Element', ['insertAdjacentElement', 'insertAdjacentHTML']],
                ['CharacterData', ['before', 'after', 'replaceWith']],
                ['DocumentType', ['before', 'after', 'replaceWith']],
                ['DocumentFragment', ['append', 'prepend', 'replaceChildren']],
                ['Document', ['append', 'prepend', 'replaceChildren', 'write', 'writeln', 'execCommand']],
                ['Range', ['insertNode', 'surroundContents']],
                ['HTMLIFrameElement', ['getSVGDocument']],
                ['HTMLObjectElement', ['getSVGDocument']],
                ['HTMLEmbedElement', ['getSVGDocument']]
            ];
            var SETTERS = [['Element', ['innerHTML', 'outerHTML']], ['ShadowRoot', ['innerHTML']], ['Document', ['body']]];
            // Each way to give an element a sandbox: by the attribute's name, at the given place, or by an attribute.
            var SANDBOX_NAMED = [['Element', ['setAttribute', 'toggleAttribute'], 0], ['Element', ['setAttributeNS'], 1]];
            var SANDBOX_NODES = [['Element', ['setAttributeNode', 'setAttributeNodeNS']], ['NamedNodeMap', ['setNamedItem', 'setNamedItemNS']]];

            function sealed(w) {
                var held = describe(w, 'RTCPeerConnection');
                return !!held && held.value === undefined && !held.configurable;
            }
            // Takes the sandbox off a frame, and takes out of the page a frame that still cannot be reached.
            function tidy(node) {
                try {
                    if (call(hasAttribute, node, ['sandbox'])) call(removeAttribute, node, ['sandbox']);
                    var tag = call(tagOf, node, []);
                    var reach = tag === 'iframe' ? iframeWindow : tag === 'frame' ? frameWindow : tag === 'object' ? objectWindow : null;
                    var w = reach && call(reach, node, []);
                    if (w) describe(w, 'RTCPeerConnection');
                } catch (error) {
                    try { call(removeNode, node, []); } catch (ignored) {}
                }
            }
            // Tidies a node and every frame or sandboxed element within it.
            function tidyWithin(node) {
                try {
                    var type = call(typeOf, node, []);
                    if (type === 1) tidy(node);
                    if (type !== 1 && type !== 9 && type !== 11) return;
                    var found = call(findAll[type], node, [FRAMES]);
                    var count = call(countOf, found, []);
                    for (var k = 0; k < count; k++) tidy(found[k]);
                } catch (error) {}
            }
            // Seals every window in the page that is not sealed yet, frames within frames included.
            function sweep(w) {
                var doc;
                try {
                    if (!sealed(w)) seal(w);
                    doc = w.document;
                } catch (error) { return; }
                tidyWithin(doc);
                try {
                    var count = call(lengthOf, w, []);
                    for (var i = 0; i < count; i++) sweep(w[i]);
                } catch (error) {}
            }
            function sweepAll() {
                sweep(root);
                if (window !== root) sweep(window);
                for (var r = 0; r < roots.length; r++) tidyWithin(roots[r]);
            }
            function wrap(w, kind, name, part, make) {
                var proto = w[kind] && w[kind].prototype;
                var held = proto && describe(proto, name);
                if (!held || typeof held[part] !== 'function') return;
                held[part] = make(held[part]);
                define(proto, name, held);
            }
            function sweptAfter(original) {
                return function () { try { return call(original, this, arguments); } finally { sweepAll(); } };
            }
            function sweptBefore(original) {
                return function () { sweepAll(); return call(original, this, arguments); };
            }
            // Takes the sandbox off whatever is about to be put in the page, then puts it in and seals what it made.
            function tidiedAndSwept(original) {
                return function () {
                    for (var a = 0; a < arguments.length; a++) tidyWithin(arguments[a]);
                    try { return call(original, this, arguments); } finally { sweepAll(); }
                };
            }
            function each(list, part, make, w) {
                for (var k = 0; k < list.length; k++) {
                    for (var n = 0; n < list[k][1].length; n++) wrap(w, list[k][0], list[k][1][n], part, make);
                }
            }
            function isSandbox(name) {
                var text = call(lower, name, []);
                return call(cut, text, [call(lastIndexOf, text, [':']) + 1]) === 'sandbox';
            }
            // Ignores a call that would set a sandbox by name; the name is read once, so it cannot change between.
            function refusingName(at) {
                return function (original) {
                    return function () {
                        var args = call(copy, arguments, []);
                        if (args.length > at) {
                            args[at] = toText(args[at]);
                            if (isSandbox(args[at])) return undefined;
                        }
                        return call(original, this, args);
                    };
                };
            }
            function refusingNode(original) {
                return function (attribute) {
                    try { if (isSandbox(call(attributeNameOf, attribute, []))) return null; } catch (error) {}
                    return call(original, this, arguments);
                };
            }
            // Takes peer connections out of one window, gives it no way to sandbox a frame, and has everything in it
            // that makes a frame or reaches one seal the new frame before the page can use it.
            function seal(w) {
                for (var i = 0; i < NAMES.length; i++) {
                    try { define(w, NAMES[i], { value: undefined, writable: false, configurable: false }); } catch (error) {}
                }
                var listen = w.EventTarget.prototype.addEventListener, Observer = w.MutationObserver;
                var observe = Observer.prototype.observe;
                var options = { childList: true, subtree: true, attributes: true, attributeFilter: ['sandbox'] };
                var watch = function (node) {
                    for (var e = 0; e < EVENTS.length; e++) call(listen, node, [EVENTS[e], sweepAll, true]);
                    call(observe, new Observer(sweepAll), [node, options]);
                };
                each(GETTERS, 'get', sweptBefore, w);
                each(METHODS, 'value', tidiedAndSwept, w);
                each(SETTERS, 'set', sweptAfter, w);
                for (var s = 0; s < SANDBOX_NAMED.length; s++) each([SANDBOX_NAMED[s]], 'value', refusingName(SANDBOX_NAMED[s][2]), w);
                each(SANDBOX_NODES, 'value', refusingNode, w);
                var spare = null;
                wrap(w, 'HTMLIFrameElement', 'sandbox', 'set', function () { return function () {}; });
                // A frame's own list of sandbox flags is never handed out: changes to the one given go nowhere.
                wrap(w, 'HTMLIFrameElement', 'sandbox', 'get', function (original) {
                    return function () {
                        spare = spare || call(makeElement, w.document, ['iframe']);
                        return call(original, spare, []);
                    };
                });
                wrap(w, 'Element', 'setHTMLUnsafe', 'value', function () {
                    return function (markup) { try { call(markupInto, this, [markup]); } finally { sweepAll(); } };
                });
                wrap(w, 'ShadowRoot', 'setHTMLUnsafe', 'value', function () {
                    return function (markup) { try { call(markupIntoShadow, this, [markup]); } finally { sweepAll(); } };
                });
                try {
                    define(w.Document, 'parseHTMLUnsafe', {
                        value: function (markup) { return call(parse, new Parser(), [toText(markup), 'text/html']); },
                        writable: false,
                        configurable: false
                    });
                } catch (error) {}
                wrap(w, 'Element', 'attachShadow', 'value', function (original) {
                    return function () {
                        var shadow = call(original, this, arguments);
                        try { define(roots, roots.length, { value: shadow }); watch(shadow); } catch (error) {}
                        return shadow;
                    };
                });
                wrap(w, 'Document', 'open', 'value', function (original) {
                    return function () {
                        try { return call(original, this, arguments); } finally {
                            try { watch(this); } catch (error) {}
                            sweepAll();
                        }
                    };
                });
                try { watch(w.document); } catch (error) {}
            }
            sweep(window);
            sweepAll();
        })();
        """
    }
}
