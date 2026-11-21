import SwiftUI

extension View {
    /// Fills a shape behind the view and draws a hairline border just inside its edge.
    ///
    /// Every bordered surface in the app is drawn through this, so that fills and borders stay in step.
    func surface<S: InsettableShape>(_ shape: S, fill: Color = HearthColor.card, border: Color = HearthColor.line) -> some View {
        background(fill, in: shape)
            .overlay { shape.strokeBorder(border, lineWidth: HearthSize.hairline) }
    }

    /// A raised, rounded rectangle: the composer, a code block, a table, the search field.
    func cardSurface(radius: CGFloat = HearthRadius.card, border: Color = HearthColor.line) -> some View {
        surface(RoundedRectangle(cornerRadius: radius, style: .continuous), border: border)
    }

    /// A see-through surface for something that floats over scrolling content, which shows softened through it.
    ///
    /// iOS 26 and later draw the system's glass. Earlier systems get a frosted fill with a hairline edge.
    @ViewBuilder
    func frostedSurface<S: InsettableShape>(_ shape: S) -> some View {
        if #available(iOS 26, *) {
            glassEffect(.clear, in: shape)
        } else {
            background(.regularMaterial, in: shape)
                .overlay { shape.strokeBorder(HearthColor.line, lineWidth: HearthSize.hairline) }
        }
    }

    /// A pill: an attached file, the caption of a voice conversation.
    func capsuleSurface(fill: Color = HearthColor.card) -> some View {
        surface(Capsule(), fill: fill)
    }

    /// A capsule's outline with nothing behind it, for a quiet control.
    func capsuleOutline(_ color: Color = HearthColor.line) -> some View {
        overlay { Capsule().strokeBorder(color, lineWidth: HearthSize.hairline) }
    }
}
