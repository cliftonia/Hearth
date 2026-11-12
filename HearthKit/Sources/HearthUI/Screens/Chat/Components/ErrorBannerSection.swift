import SwiftUI

/// An error shown above the composer, with a way to retry where that makes sense and a way to dismiss it.
struct ErrorBannerSection: View {
    private static let dismissButtonSize = CGSize(width: 24, height: 20)
    private static let messageLineLimit = 4

    let configuration: ErrorViewConfiguration
    let retryAction: () -> Void
    let dismissAction: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: HearthSpacing.s10) {
            VStack(alignment: .leading, spacing: HearthSpacing.s2) {
                Text(configuration.title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(HearthColor.ink)
                Text(configuration.message)
                    .font(.footnote)
                    .foregroundStyle(HearthColor.mute)
                    .lineLimit(Self.messageLineLimit)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let retryActionLabel = configuration.retryActionLabel {
                Button(retryActionLabel, action: retryAction)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(HearthColor.pine)
                    .buttonStyle(.plain)
            }
            Button(action: dismissAction) {
                Image(systemName: "xmark")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(HearthColor.mute)
                    .frame(size: Self.dismissButtonSize)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Strings.dismiss)
        }
        .padding(HearthSpacing.s12)
        .cardSurface(radius: HearthRadius.banner, border: HearthColor.danger.opacity(0.5))
        .padding(.horizontal, HearthSpacing.s12)
        .padding(.top, HearthSpacing.s6)
    }
}
