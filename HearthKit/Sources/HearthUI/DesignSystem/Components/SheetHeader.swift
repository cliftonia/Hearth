import SwiftUI

/// The top of a sheet: its title in the middle, and a round close button at the trailing edge, where every sheet that
/// is not an editor keeps it (an editor has Cancel and Done instead).
///
/// The button and an empty slot as wide at the other edge keep the title centred and clear of the button, so a long
/// title at a large text size wraps between them rather than running under it.
struct SheetHeader: View {
    private static let closeButtonSide: CGFloat = 36

    let title: String
    /// Run when the close button is tapped.
    let closeAction: @MainActor () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: HearthSpacing.s8) {
            Color.clear
                .frame(width: HearthSize.minimumHitTarget, height: 0)
                .accessibilityHidden(true)
            Text(title)
                .font(.hearth(.headline))
                .foregroundStyle(HearthColor.ink)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
                .frame(maxWidth: .infinity)
            closeButton
                .frame(width: HearthSize.minimumHitTarget, alignment: .trailing)
        }
        .padding(.horizontal, HearthSpacing.s16)
        .padding(.top, HearthSpacing.s24)
        .padding(.bottom, HearthSpacing.s16)
    }

    private var closeButton: some View {
        Button(action: closeAction) {
            Image(systemName: "xmark")
                .font(.hearth(.footnote).weight(.semibold))
                .iconGlyphSize()
                .foregroundStyle(HearthColor.ink)
                .frame(width: Self.closeButtonSide, height: Self.closeButtonSide)
                .surface(Circle())
                .minimumHitTarget()
                .hoverHighlight(Circle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.cancelAction)
        .accessibilityLabel(Strings.close)
        .largeContentLabel(Strings.close, systemImage: "xmark")
    }
}
