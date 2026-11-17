import SwiftUI

/// The small capitals above a group of rows: a caption in the muted colour, read by VoiceOver as a heading.
///
/// The space around it belongs to where it is placed, so the caller pads it.
struct SectionHeading: View {
    let title: String
    /// Extra space between the letters, for a heading that should read as a label more than a title.
    var kerning: CGFloat = 0

    var body: some View {
        Text(title)
            .font(.hearth(.caption).weight(.medium))
            .textCase(.uppercase)
            .kerning(kerning)
            .foregroundStyle(HearthColor.mute)
            .accessibilityAddTraits(.isHeader)
    }
}
