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
                .foregroundStyle(HearthColor.ink)
                .frame(width: HearthSize.iconButton, height: HearthSize.iconButton)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
