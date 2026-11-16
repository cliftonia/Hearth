import SwiftUI

/// A round button holding one symbol, set in a bubble of glass that floats over the chat like the composer.
///
/// On iOS 26 and later the bubble is the system's own interactive glass; before that it is a frosted circle with a
/// hairline edge and a soft shadow. A button that switches something shows when it is on with a tint of pine.
struct GlassCircleButton: View {
    let systemImage: String
    /// What VoiceOver reads, since the button shows no text.
    let label: String
    /// Whether what the button switches is on. `nil` for a button that only acts.
    var isSelected: Bool?
    let action: () -> Void

    var body: some View {
        let isOn = isSelected == true
        Button(action: action) {
            Image(systemName: systemImage)
                .font(HearthFont.icon)
                .foregroundStyle(isOn ? HearthColor.pine : HearthColor.ink)
                .frame(width: HearthSize.glassButton, height: HearthSize.glassButton)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassSurface(Circle(), tint: isOn ? HearthColor.pineSoft : nil)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

extension View {
    /// Sets the view in a bubble of glass of the given shape, tinted when given a colour.
    ///
    /// iOS 26 and later draw the system's interactive glass. Earlier systems get a frosted fill with a hairline edge
    /// and the floating shadow, or the tint itself when there is one.
    @ViewBuilder
    func glassSurface<S: InsettableShape>(_ shape: S, tint: Color? = nil) -> some View {
        if #available(iOS 26, *) {
            glassEffect(tint.map { Glass.regular.tint($0).interactive() } ?? .regular.interactive(), in: shape)
        } else {
            background {
                if let tint {
                    shape.fill(tint)
                } else {
                    shape.fill(.regularMaterial)
                }
            }
            .overlay { shape.strokeBorder(HearthColor.line, lineWidth: HearthSize.hairline) }
            .hearthShadow(.floating)
        }
    }
}
