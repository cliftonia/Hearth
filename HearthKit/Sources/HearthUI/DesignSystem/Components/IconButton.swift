import SwiftUI

/// A round, borderless button holding one symbol.
struct IconButton: View {
    let systemImage: String
    /// What VoiceOver reads, since the button shows no text.
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(HearthFont.icon)
                .iconGlyphSize()
                .foregroundStyle(HearthColor.ink)
                .frame(width: HearthSize.iconButton, height: HearthSize.iconButton)
                .minimumHitTarget()
                .hoverHighlight(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .largeContentLabel(label, systemImage: systemImage)
    }
}
