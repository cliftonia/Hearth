import HearthDomain
import SwiftUI
import UIKit

/// What the plus button opens on a phone or a tablet: a heading with the way out and the photo library either side
/// of it, the latest photos, then cards of rows. The first card holds the things to add, the second the things to
/// make, and the last the switches, which are thrown where they stand without closing the sheet.
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
    /// The latest photos in the library, asked for as the sheet opens; none without leave to read it.
    let loadRecentPhotos: () async -> [RecentPhoto]
    /// Run with one of the latest photos that was tapped; the sheet is then closed by whoever opened it.
    let choosePhotoAction: (RecentPhoto.ID) -> Void

    @State private var recentPhotos: [RecentPhoto] = []

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var rowSymbolWidth: CGFloat = 28

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: HearthSpacing.s16) {
                    RecentPhotoStrip(photos: recentPhotos, chooseAction: choosePhotoAction)
                        .folded(recentPhotos.isEmpty)
                    // The cards keep clear of the sheet's edges; the photos above them run right to the edges.
                    ForEach(groups, id: \.self) { group in
                        card(group) { row($0) }
                            .padding(.horizontal, HearthSpacing.s16)
                    }
                    card(switches) { switchRow($0) }
                        .padding(.horizontal, HearthSpacing.s16)
                        .folded(switches.isEmpty)
                }
                .padding(.bottom, HearthSpacing.s24)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(HearthColor.paper.ignoresSafeArea())
        .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.medium, .large])
        .presentationDragIndicator(.visible)
        .task {
            // Photos are offered only where they can be added, so the library is not asked for otherwise.
            if isEnabled(.photoLibrary) {
                recentPhotos = await loadRecentPhotos()
            }
        }
        .animation(.snappy, value: recentPhotos)
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
        let isOn = isOn(choice)
        return Button(action: { chooseAction(choice) }, label: {
            HStack(spacing: HearthSpacing.s12) {
                label(choice)
                // A row that is on, such as picture mode, says so with a tick; tapping it again turns it off.
                Image(systemName: "checkmark")
                    .font(.hearth(.footnote).weight(.semibold))
                    .foregroundStyle(HearthColor.pine)
                    .opacity(isOn ? 1 : 0)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, HearthSpacing.s16)
            .padding(.vertical, HearthSpacing.s16)
            .contentShape(Rectangle())
        })
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
        .accessibilityLabel(choice.title)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    /// A row with a switch, thrown by a tap anywhere on the row.
    private func switchRow(_ choice: AttachmentChoiceKind) -> some View {
        ActionSwitch(isOn: isOn(choice), toggleAction: { toggleAction(choice) }, label: { label(choice) })
            .padding(.horizontal, HearthSpacing.s16)
            .padding(.vertical, HearthSpacing.s12)
    }
}

/// The latest photos side by side, running off the sheet's edge, each added to the message by a tap.
private struct RecentPhotoStrip: View {
    let photos: [RecentPhoto]
    let chooseAction: (RecentPhoto.ID) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: HearthSpacing.s8) {
                ForEach(photos.enumerated().map { Numbered(number: $0.offset + 1, photo: $0.element) }) { entry in
                    Button(action: { chooseAction(entry.photo.id) }, label: {
                        Image(uiImage: UIImage(data: entry.photo.thumbnailJPEG) ?? UIImage())
                            .resizable()
                            .scaledToFill()
                            .frame(width: PhotoLibraryProvider.recentPhotoSide, height: PhotoLibraryProvider.recentPhotoSide)
                            .clipShape(RoundedRectangle(cornerRadius: HearthRadius.card, style: .continuous))
                            .contentShape(Rectangle())
                    })
                    .buttonStyle(.plain)
                    .accessibilityLabel(Strings.recentPhoto(number: entry.number, total: photos.count))
                }
            }
            // The first photo lines up with the cards beneath; the rest run off the sheet's edge.
            .padding(.horizontal, HearthSpacing.s16)
        }
    }

    /// A photo and its place in the strip, which is how VoiceOver tells one from the next.
    private struct Numbered: Identifiable {
        let number: Int
        let photo: RecentPhoto

        var id: RecentPhoto.ID { photo.id }
    }
}
