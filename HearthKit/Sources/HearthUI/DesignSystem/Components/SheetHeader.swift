import SwiftUI

/// The top of a sheet: its title in the middle, and a round close button at the leading edge.
struct SheetHeader: View {
    private static let closeButtonSide: CGFloat = 36

    let title: String
    /// Run when the close button is tapped.
    let closeAction: @MainActor () -> Void

    var body: some View {
        Text(title)
            .font(.hearth(.headline))
            .foregroundStyle(HearthColor.ink)
            .accessibilityAddTraits(.isHeader)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .leading) {
                Button(action: closeAction) {
                    Image(systemName: "xmark")
                        .font(.hearth(.footnote).weight(.semibold))
                        .foregroundStyle(HearthColor.ink)
                        .frame(width: Self.closeButtonSide, height: Self.closeButtonSide)
                        .surface(Circle())
                        .minimumHitTarget()
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Strings.close)
            }
            .padding(.horizontal, HearthSpacing.s16)
            .padding(.top, HearthSpacing.s24)
            .padding(.bottom, HearthSpacing.s16)
    }
}
