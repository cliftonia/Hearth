import SwiftUI

/// A page pushed from the settings: cards on paper, scrolled, under an inline title.
struct SettingsPage<Content: View>: View {
    /// The widest the cards grow, so that on an iPad or a Mac they stay a comfortable column.
    private static var maximumWidth: CGFloat { 560 }

    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HearthSpacing.s24) {
                content
            }
            .padding(HearthSpacing.s16)
            .frame(maxWidth: Self.maximumWidth)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(HearthColor.paper.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// One card on a settings page, with a small heading above it in Title Case and a line of explanation beneath,
/// where given. Rows inside it are divided with `Hairline`.
struct SettingsCard<Content: View>: View {
    var header: String?
    var footer: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: HearthSpacing.s6) {
            Text(header ?? "")
                .font(.hearth(.footnote).weight(.medium))
                .textCase(nil)
                .foregroundStyle(HearthColor.mute)
                .padding(.horizontal, HearthSpacing.s4)
                .accessibilityAddTraits(.isHeader)
                .folded(header == nil)
            VStack(spacing: 0) {
                content
            }
            .cardSurface(radius: HearthRadius.bubble)
            Text(footer ?? "")
                .font(.hearth(.footnote))
                .foregroundStyle(HearthColor.mute)
                .padding(.horizontal, HearthSpacing.s4)
                .folded(footer == nil)
        }
    }
}

/// A switch in a card: what it is, and one line on what it does.
struct SettingsSwitchRow: View {
    let title: String
    var detail: String?
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: HearthSpacing.s2) {
                Text(title)
                    .font(.hearth(.body))
                    .foregroundStyle(HearthColor.ink)
                Text(detail ?? "")
                    .font(.hearth(.footnote))
                    .foregroundStyle(HearthColor.mute)
                    .frame(height: detail == nil ? 0 : nil)
            }
        }
        .tint(HearthColor.pine)
        .padding(.horizontal, HearthSpacing.s16)
        .padding(.vertical, HearthSpacing.s12)
    }
}
