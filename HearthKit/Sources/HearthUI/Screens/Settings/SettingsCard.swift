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

/// One card on a settings page, with a small heading above it and a line of explanation beneath, where given.
/// Rows inside it are divided with `Hairline`.
struct SettingsCard<Content: View>: View {
    var header: String?
    var footer: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: HearthSpacing.s6) {
            Text(header ?? "")
                .font(.caption.weight(.medium))
                .textCase(.uppercase)
                .foregroundStyle(HearthColor.mute)
                .padding(.horizontal, HearthSpacing.s4)
                .frame(height: header == nil ? 0 : nil)
                .opacity(header == nil ? 0 : 1)
                .accessibilityHidden(header == nil)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
                content
            }
            .cardSurface(radius: HearthRadius.bubble)
            Text(footer ?? "")
                .font(.footnote)
                .foregroundStyle(HearthColor.mute)
                .padding(.horizontal, HearthSpacing.s4)
                .frame(height: footer == nil ? 0 : nil)
                .opacity(footer == nil ? 0 : 1)
                .accessibilityHidden(footer == nil)
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
                    .font(.body)
                    .foregroundStyle(HearthColor.ink)
                Text(detail ?? "")
                    .font(.footnote)
                    .foregroundStyle(HearthColor.mute)
                    .frame(height: detail == nil ? 0 : nil)
            }
        }
        .tint(HearthColor.pine)
        .padding(.horizontal, HearthSpacing.s16)
        .padding(.vertical, HearthSpacing.s12)
    }
}
