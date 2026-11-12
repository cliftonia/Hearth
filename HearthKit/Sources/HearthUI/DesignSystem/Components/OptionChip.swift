import SwiftUI

/// An icon-only capsule for a switch: filled when the switch is on, outlined when it is off.
///
/// This is only the label. Wrap it in a `Button` or a `Menu`, which also carries the accessibility label.
struct OptionChip: View {
    let systemImage: String
    let isOn: Bool

    var body: some View {
        Image(systemName: systemImage)
            .font(.footnote.weight(.medium))
            .foregroundStyle(isOn ? HearthColor.pine : HearthColor.mute)
            .frame(size: HearthSize.optionChip)
            .surface(Capsule(), fill: isOn ? HearthColor.pineSoft : .clear, border: isOn ? .clear : HearthColor.line)
    }
}
