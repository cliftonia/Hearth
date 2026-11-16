import Foundation

/// Takes declarative shadow roots out of a page before the canvas loads it.
///
/// The parser turns a `<template shadowrootmode="open">` (or `"closed"`) into a shadow root of the element around it,
/// without any script being run, so the start script never sees it made and its sweep of the page's frames does not
/// look inside it. A frame hidden there, sandboxed or not, would be beyond its reach. So every attribute that asks for
/// such a root is renamed before the page is loaded: the template is then an ordinary template, whose contents stay
/// inert and out of the page, and nothing else about the page changes.
///
/// The names are matched wherever an attribute's name can begin and end, with no attempt to read the markup as the
/// parser would (an attribute's value may hold a `>`, a stray quote ends no attribute, and so on): renaming one too
/// many does no harm, and missing one would. So the words also change in the page's own text, where one stands alone
/// in a sentence about shadow roots.
public enum CanvasShadowRootTransformer {
    /// The attributes that make, or describe, a declarative shadow root, as the parser reads them in any case.
    public static let attributeNames = [
        "shadowrootmode", "shadowroot", "shadowrootdelegatesfocus", "shadowrootclonable", "shadowrootserializable"
    ]
    /// What each is renamed to begin with: a data attribute, which nothing reads.
    public static let inertPrefix = "data-hearth-"

    /// The page with every attribute that would make a declarative shadow root renamed with `inertPrefix`.
    ///
    /// A name is matched with what may stand before it (space, `/` or a quote that ends the attribute before) and
    /// after it (space, `=`, `/`, `>` or the end), in any case. It is read scalar by scalar, so that a line break of
    /// two characters or an accent added to a mark is not read as one character.
    public static func inert(_ markup: String) -> String {
        let attribute = /([\t\n\f\r "'\/])(shadowroot(?:mode|delegatesfocus|clonable|serializable)?)(?=[\t\n\f\r =\/>]|\z)/
        return markup.replacing(attribute.matchingSemantics(.unicodeScalar).ignoresCase()) { match in
            "\(match.output.1)\(inertPrefix)\(match.output.2)"
        }
    }
}
