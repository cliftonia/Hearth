import SwiftUI

/// A card saying that the system is holding something back, with a button that leads to where that is changed.
struct PermissionNotice: View {
    let systemImage: String
    let message: String
    /// The button's title, or `nil` when there is nowhere to send the user.
    let actionTitle: String?
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: HearthSpacing.s8) {
            Label(message, systemImage: systemImage)
                .font(.hearth(.footnote))
                .foregroundStyle(HearthColor.ink)
            if let actionTitle {
                Button(actionTitle, action: action)
                    .font(.hearth(.footnote).weight(.semibold))
                    .foregroundStyle(HearthColor.pine)
                    .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(HearthSpacing.s12)
        .cardSurface(radius: HearthRadius.banner, border: HearthColor.danger.opacity(0.5))
    }
}
