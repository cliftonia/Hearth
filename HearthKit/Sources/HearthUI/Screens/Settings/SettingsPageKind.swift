import SwiftUI

/// The pages the settings lead on to.
///
/// A row opens its page by adding it to the settings' path with a plain button. A `NavigationLink` in the list,
/// whether it held its destination or a value, was pushed again on the Mac each time its row changed, and the
/// profile row changes with every letter of the name typed on the page it opens, so going back landed on that page.
enum SettingsPageKind: Hashable {
    case profile
    case memories
    case webSearch
    case tasks
    case voice
    case pictures
    case notifications
    case servers
    case sync
}

/// A row in the settings that opens a page: its own content, and a chevron at the end.
struct SettingsLinkRow<Label: View>: View {
    /// The row's own content sits inside the list's insets, so the pointer's highlight reaches a little past it.
    static var hoverShape: some InsettableShape {
        RoundedRectangle(cornerRadius: HearthRadius.row, style: .continuous).inset(by: -HearthSpacing.s6)
    }

    let action: () -> Void
    /// What VoiceOver reads for the row; without one it reads the row's content.
    var accessibilityLabel: String?
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
            .hoverHighlight(Self.hoverShape)
        }
        .buttonStyle(.plain)
        .foregroundStyle(HearthColor.ink)
        .modifier(OptionalAccessibilityLabel(label: accessibilityLabel))
    }
}

/// Gives a view an accessibility label when there is one, and leaves it as it is when there is not.
private struct OptionalAccessibilityLabel: ViewModifier {
    let label: String?

    func body(content: Content) -> some View {
        if let label {
            content.accessibilityLabel(label)
        } else {
            content
        }
    }
}

/// A row of the main list that leads to a page: its title, and beneath it a line saying how things stand there,
/// both read by VoiceOver as one ("Memory, On, 12 saved").
struct SettingsStatusRow: View {
    let title: String
    let status: String
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        SettingsLinkRow(action: action, accessibilityLabel: SettingsPresenter.accessibilityLabel(title: title, status: status)) {
            VStack(alignment: .leading, spacing: HearthSpacing.s2) {
                Text(title)
                    .font(.hearth(.body))
                    .foregroundStyle(isEnabled ? HearthColor.ink : HearthColor.mute)
                Text(status)
                    .font(.hearth(.footnote))
                    .foregroundStyle(HearthColor.mute)
            }
        }
        .disabled(!isEnabled)
    }
}

/// Keeps what was typed in a field when the field is left or submitted, not with every letter.
struct KeepOnLeavingField: ViewModifier {
    let action: () -> Void

    @FocusState private var isFocused: Bool

    func body(content: Content) -> some View {
        content
            .focused($isFocused)
            .onSubmit(action)
            .onChange(of: isFocused) {
                if !isFocused {
                    action()
                }
            }
    }
}

extension View {
    /// Calls `action` when this field is left or submitted, so that what was typed is kept then.
    func keepOnLeaving(_ action: @escaping () -> Void) -> some View {
        modifier(KeepOnLeavingField(action: action))
    }
}
