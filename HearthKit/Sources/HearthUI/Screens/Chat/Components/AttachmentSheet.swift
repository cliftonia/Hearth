import SwiftUI

/// What the plus button opens on a phone or a tablet: a heading with the way out and the photo library either side
/// of it, then cards of rows. The first card holds the things to add, the second the things to make, and the last
/// the switches, which are thrown where they stand without closing the sheet.
struct AttachmentSheet: View {
    private static let closeButtonSide: CGFloat = 36

    /// The things to add to the message, and the things to make.
    let groups: [[AttachmentChoiceKind]]
    /// The switches: what the next message asks for, and how replies are given.
    let switches: [AttachmentChoiceKind]
    let isEnabled: (AttachmentChoiceKind) -> Bool
    let isOn: (AttachmentChoiceKind) -> Bool
    /// Run with a row that was tapped; the sheet is then closed by whoever opened it.
    let chooseAction: (AttachmentChoiceKind) -> Void
    /// Run with a switch that was thrown; the sheet stays open.
    let toggleAction: (AttachmentChoiceKind) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var rowSymbolWidth: CGFloat = 28

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: HearthSpacing.s16) {
                    ForEach(groups, id: \.self) { group in
                        card(group) { row($0) }
                    }
                    card(switches) { switchRow($0) }
                        .folded(switches.isEmpty)
                }
                .padding(.horizontal, HearthSpacing.s16)
                .padding(.bottom, HearthSpacing.s24)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(HearthColor.paper.ignoresSafeArea())
        .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: The heading

    /// The way out, the sheet's name, and the photo library, which is the commonest thing to add.
    private var header: some View {
        let canAddPhotos = isEnabled(.photoLibrary)
        return ZStack {
            Text(Strings.addToChat)
                .font(.hearth(.headline))
                .foregroundStyle(HearthColor.ink)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: HearthSpacing.s8) {
                Button(action: { dismiss() }, label: {
                    Image(systemName: "xmark")
                        .font(.hearth(.footnote).weight(.semibold))
                        .iconGlyphSize()
                        .foregroundStyle(HearthColor.ink)
                        .frame(width: Self.closeButtonSide, height: Self.closeButtonSide)
                        .surface(Circle())
                        .minimumHitTarget()
                })
                .buttonStyle(.plain)
                .accessibilityLabel(Strings.close)
                .frame(maxWidth: .infinity, alignment: .leading)
                Button(action: { chooseAction(.photoLibrary) }, label: {
                    Text(Strings.photos)
                        .font(.hearth(.body).weight(.medium))
                        .foregroundStyle(HearthColor.ink)
                        .minimumHitTarget()
                        .contentShape(Rectangle())
                })
                .buttonStyle(.plain)
                .disabled(!canAddPhotos)
                .opacity(canAddPhotos ? 1 : 0.4)
                .accessibilityLabel(AttachmentChoiceKind.photoLibrary.title)
            }
        }
        .padding(.horizontal, HearthSpacing.s16)
        .padding(.top, HearthSpacing.s24)
        .padding(.bottom, HearthSpacing.s16)
    }

    // MARK: The cards

    /// Rows one under another in a card, with a line between each two.
    private func card(_ choices: [AttachmentChoiceKind], @ViewBuilder row: @escaping (AttachmentChoiceKind) -> some View) -> some View {
        VStack(spacing: 0) {
            ForEach(choices) { choice in
                row(choice)
                Hairline()
                    .padding(.leading, HearthSpacing.s16 + rowSymbolWidth + HearthSpacing.s12)
                    .padding(.trailing, HearthSpacing.s16)
                    .opacity(choice == choices.last ? 0 : 1)
            }
        }
        .cardSurface(radius: HearthRadius.composer)
    }

    /// The symbol and the name every row begins with.
    private func label(_ choice: AttachmentChoiceKind) -> some View {
        HStack(spacing: HearthSpacing.s12) {
            Image(systemName: choice.systemImage)
                .font(.hearth(.body))
                .foregroundStyle(HearthColor.ink)
                .frame(width: rowSymbolWidth)
                .accessibilityHidden(true)
            Text(choice.title)
                .font(.hearth(.body))
                .foregroundStyle(HearthColor.ink)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// A row that does something and closes the sheet.
    private func row(_ choice: AttachmentChoiceKind) -> some View {
        let isEnabled = isEnabled(choice)
        return Button(action: { chooseAction(choice) }, label: {
            label(choice)
                .padding(.horizontal, HearthSpacing.s16)
                .padding(.vertical, HearthSpacing.s16)
                .contentShape(Rectangle())
        })
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
        .accessibilityLabel(choice.title)
    }

    /// A row with a switch, thrown by a tap anywhere on the row.
    private func switchRow(_ choice: AttachmentChoiceKind) -> some View {
        AttachmentSwitch(isOn: isOn(choice), toggleAction: { toggleAction(choice) }, label: { label(choice) })
            .padding(.horizontal, HearthSpacing.s16)
            .padding(.vertical, HearthSpacing.s12)
    }
}

/// A switch that shows what it is told is so, and asks for a change when it is thrown.
///
/// The switch keeps its own position while it moves and is set right again by whatever it is told, so a change
/// that is refused, or one made elsewhere, is shown as it is.
private struct AttachmentSwitch<Label: View>: View {
    let isOn: Bool
    let toggleAction: () -> Void
    @ViewBuilder let label: () -> Label

    @State private var position = false

    var body: some View {
        Toggle(isOn: $position, label: label)
            .tint(HearthColor.pine)
            .onAppear { position = isOn }
            .onChange(of: isOn) { position = isOn }
            .onChange(of: position) {
                if position != isOn {
                    toggleAction()
                }
            }
    }
}
