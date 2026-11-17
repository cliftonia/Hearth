import SwiftUI

extension View {
    /// Shows, quietly, that a pointer is over a control drawn without the system's own button style: the system's
    /// highlight under an iPad's pointer, and a faint wash of ink over it on a Mac, whose pointer has no effect of
    /// its own on a plain button. Touch alone shows nothing.
    ///
    /// Put it on the control's label, after `.minimumHitTarget()`, with the shape the control is drawn in. A shape
    /// grown past the label, as with `inset(by:)` and a negative amount, lights a little room around it.
    func hoverHighlight<S: Shape>(_ shape: S) -> some View {
        modifier(HoverHighlight(shape: shape))
    }
}

/// How the pointer over a control is shown, by platform.
private struct HoverHighlight<S: Shape>: ViewModifier {
    /// How much of the ink is washed behind a control under the pointer on a Mac.
    private static var washOpacity: Double { 0.07 }

    let shape: S

    @State private var isHovered = false

    func body(content: Content) -> some View {
        #if targetEnvironment(macCatalyst)
        content
            // Over the control rather than behind it, so a filled one shows it too.
            .overlay {
                shape
                    .fill(HearthColor.ink.opacity(isHovered ? Self.washOpacity : 0))
                    .allowsHitTesting(false)
            }
            .onHover { isHovered = $0 }
            .animation(.easeOut(duration: 0.12), value: isHovered)
        #else
        content
            .contentShape(.hoverEffect, shape)
            .hoverEffect(.highlight)
        #endif
    }
}
