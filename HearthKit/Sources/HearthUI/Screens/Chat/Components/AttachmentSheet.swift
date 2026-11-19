import SwiftUI

/// What the plus button opens on a phone or a tablet: the things to attach as a row of large buttons, and under
/// them the switches and the things to make, as a list.
struct AttachmentSheet: View {
    private static let tileHeight: CGFloat = 84

    let attachments: [AttachmentChoiceKind]
    let extras: [AttachmentChoiceKind]
    let isEnabled: (AttachmentChoiceKind) -> Bool
    let isOn: (AttachmentChoiceKind) -> Bool
    /// Run with what was tapped; the sheet is then closed by whoever opened it.
    let chooseAction: (AttachmentChoiceKind) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var rowSymbolWidth: CGFloat = 26

    var body: some View {
        ScrollView {
            VStack(spacing: HearthSpacing.s16) {
                // At the largest text sizes three buttons side by side would each hold a word or less.
                if dynamicTypeSize.isAccessibilitySize {
                    list(attachments)
                } else {
                    HStack(spacing: HearthSpacing.s10) {
                        ForEach(attachments) { tile($0) }
                    }
                }
                list(extras)
            }
            .padding(.horizontal, HearthSpacing.s16)
            .padding(.top, HearthSpacing.s28)
            .padding(.bottom, HearthSpacing.s16)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(HearthColor.paper.ignoresSafeArea())
        .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.medium])
        .presentationDragIndicator(.visible)
    }

    /// One of the large buttons: a symbol over its name.
    private func tile(_ choice: AttachmentChoiceKind) -> some View {
        let isEnabled = isEnabled(choice)
        return Button(action: { chooseAction(choice) }, label: {
            VStack(spacing: HearthSpacing.s8) {
                Image(systemName: choice.systemImage)
                    .font(.hearth(.title3))
                    .accessibilityHidden(true)
                Text(choice.title)
                    .font(.hearth(.footnote))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(HearthColor.ink)
            .padding(.horizontal, HearthSpacing.s6)
            .frame(maxWidth: .infinity, minHeight: Self.tileHeight)
            .cardSurface()
            .contentShape(Rectangle())
            .hoverHighlight(RoundedRectangle(cornerRadius: HearthRadius.card, style: .continuous))
        })
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
        .accessibilityLabel(choice.title)
    }

    /// The choices one under another in a card, a switched-on one marked with a tick.
    private func list(_ choices: [AttachmentChoiceKind]) -> some View {
        VStack(spacing: 0) {
            ForEach(choices) { choice in
                row(choice)
                Hairline()
                    .padding(.leading, HearthSpacing.s14 + rowSymbolWidth + HearthSpacing.s12)
                    .opacity(choice == choices.last ? 0 : 1)
            }
        }
        .cardSurface()
    }

    private func row(_ choice: AttachmentChoiceKind) -> some View {
        let isEnabled = isEnabled(choice)
        let isOn = isOn(choice)
        return Button(action: { chooseAction(choice) }, label: {
            HStack(spacing: HearthSpacing.s12) {
                Image(systemName: choice.systemImage)
                    .font(.hearth(.body))
                    .foregroundStyle(isOn ? HearthColor.pine : HearthColor.mute)
                    .frame(width: rowSymbolWidth)
                    .accessibilityHidden(true)
                Text(choice.title)
                    .font(.hearth(.body))
                    .foregroundStyle(HearthColor.ink)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "checkmark")
                    .font(.hearth(.footnote).weight(.semibold))
                    .foregroundStyle(HearthColor.pine)
                    .opacity(isOn ? 1 : 0)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, HearthSpacing.s14)
            .padding(.vertical, HearthSpacing.s14)
            .contentShape(Rectangle())
        })
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
        .accessibilityLabel(choice.title)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
