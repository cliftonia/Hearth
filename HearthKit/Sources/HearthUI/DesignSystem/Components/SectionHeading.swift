import SwiftUI

/// The words above a group of rows, in the muted colour, read by VoiceOver as a heading: small capitals, or, where
/// `isQuiet`, plain words a little larger, as above the groups of the chat list.
///
/// The space around it belongs to where it is placed, so the caller pads it.
struct SectionHeading: View {
    let title: String
    /// Whether it is set as plain words rather than small capitals.
    var isQuiet = false

    var body: some View {
        Text(title)
            .font(isQuiet ? .hearth(.footnote) : .hearth(.caption).weight(.medium))
            .textCase(isQuiet ? nil : .uppercase)
            .foregroundStyle(HearthColor.mute)
            .accessibilityAddTraits(.isHeader)
    }
}
