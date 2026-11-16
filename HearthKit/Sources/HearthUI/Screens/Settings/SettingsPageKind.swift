import SwiftUI

/// The pages the settings lead on to.
///
/// A row opens its page by adding it to the settings' path with a plain button. A `NavigationLink` in the list,
/// whether it held its destination or a value, was pushed again on the Mac each time its row changed, and the
/// profile row changes with every letter of the name typed on the page it opens, so going back landed on that page.
enum SettingsPageKind: Hashable {
    case profile
    case memories
    case notifications
    case sync
}

/// A row in the settings that opens a page: its own content, and a chevron at the end.
struct SettingsLinkRow<Label: View>: View {
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    var body: some View {
        Button(action: action) {
            HStack(spacing: HearthSpacing.s8) {
                label()
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.hearth(.footnote).weight(.semibold))
                    .foregroundStyle(HearthColor.mute)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(HearthColor.ink)
    }
}
