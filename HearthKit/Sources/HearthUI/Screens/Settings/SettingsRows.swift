import SwiftUI

/// A server's address under a small caption, typed without autocorrection. It is kept once the field is left.
struct AddressFieldRow: View {
    let title: String
    @Binding var text: String
    /// Run when the field is left, by moving on or by closing the page.
    let leaveAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: HearthSpacing.s2) {
            Text(title)
                .font(.hearth(.caption))
                .foregroundStyle(HearthColor.mute)
                .accessibilityHidden(true)
            TextField("https://", text: $text)
                .font(.hearth(.body))
                .foregroundStyle(HearthColor.ink)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityLabel(title)
                .keepOnLeaving(leaveAction)
        }
        .padding(.horizontal, HearthSpacing.s16)
        .padding(.vertical, HearthSpacing.s10)
    }
}

/// A row of a card that does something at once, drawn as a symbol and a title in the brand colour.
struct SettingsActionRow: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action, label: {
            Label(title, systemImage: systemImage)
                .font(.hearth(.body))
                .foregroundStyle(HearthColor.pine)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, HearthSpacing.s16)
                .padding(.vertical, HearthSpacing.s14)
                .contentShape(Rectangle())
                .hoverHighlight(Rectangle())
        })
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

/// The outcome of a check run from a card, such as testing a server; nothing until one has been run. It is kept in
/// the tree and folded away while there is none.
struct CheckResultLine: View {
    /// Where a check has got to.
    enum OutcomeKind: Hashable {
        case idle
        case checking
        /// It worked, said in these words.
        case succeeded(String)
        /// It failed, for the reason given.
        case failed(String)
    }

    let outcome: OutcomeKind

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.hearth(.footnote))
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, HearthSpacing.s16)
            .padding(.bottom, outcome == .idle ? 0 : HearthSpacing.s12)
            .folded(outcome == .idle)
    }

    private var text: String {
        switch outcome {
        case .idle:
            ""
        case .checking:
            Strings.checking
        case .succeeded(let message), .failed(let message):
            message
        }
    }

    private var systemImage: String {
        switch outcome {
        case .idle:
            "circle"
        case .checking:
            "ellipsis"
        case .succeeded:
            "checkmark.circle.fill"
        case .failed:
            "exclamationmark.triangle.fill"
        }
    }

    /// Success is said in pine rather than the online green, which is too light to read as text.
    private var color: Color {
        switch outcome {
        case .idle, .checking:
            HearthColor.mute
        case .succeeded:
            HearthColor.pine
        case .failed:
            HearthColor.danger
        }
    }
}
