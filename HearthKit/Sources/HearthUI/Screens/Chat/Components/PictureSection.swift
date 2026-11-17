import SwiftUI
import UIKit

/// A picture the app made, shown in a reply, with ways to keep it: save to Photos, share, or copy.
struct PictureSection: View {
    /// The widest a picture is shown, so that it sits in the column like the text around it.
    private static let maximumSide: CGFloat = 420

    let pictureJPEG: Data
    /// Adds the picture to the photo library, answering whether it was added. A failure is reported by the presenter.
    let saveAction: () async -> Bool

    @State private var savedCount = 0

    var body: some View {
        if let image = DecodedImages.image(from: pictureJPEG) {
            VStack(alignment: .leading, spacing: HearthSpacing.s8) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: Self.maximumSide, maxHeight: Self.maximumSide, alignment: .leading)
                    .clipShape(RoundedRectangle(cornerRadius: HearthRadius.card, style: .continuous))
                    .accessibilityLabel(Strings.picture)
                    .contextMenu { menu(for: image) }
                HStack(spacing: HearthSpacing.s4) {
                    Button(action: save, label: {
                        Label(Strings.pictureSave, systemImage: "square.and.arrow.down")
                            .font(.hearth(.footnote).weight(.medium))
                            .foregroundStyle(HearthColor.ink)
                            .padding(.horizontal, HearthSpacing.s12)
                            .padding(.vertical, HearthSpacing.s6)
                            .capsuleOutline()
                    })
                    .buttonStyle(.plain)
                    ShareLink(item: Image(uiImage: image), preview: SharePreview(Strings.picture, image: Image(uiImage: image))) {
                        Label(Strings.share, systemImage: "square.and.arrow.up")
                            .font(.hearth(.footnote).weight(.medium))
                            .foregroundStyle(HearthColor.ink)
                            .padding(.horizontal, HearthSpacing.s12)
                            .padding(.vertical, HearthSpacing.s6)
                            .capsuleOutline()
                    }
                    .buttonStyle(.plain)
                }
            }
            .haptic(.success, trigger: savedCount)
        }
    }

    @ViewBuilder
    private func menu(for image: UIImage) -> some View {
        Button(action: save, label: {
            Label(Strings.pictureSave, systemImage: "square.and.arrow.down")
        })
        Button(action: {
            UIPasteboard.general.image = image
            Haptics.play(.success)
        }, label: {
            Label(Strings.copy, systemImage: "doc.on.doc")
        })
    }

    /// Adds the picture to the photo library, and confirms it only once it is there. iOS asks for leave the first time.
    private func save() {
        Task {
            if await saveAction() {
                savedCount += 1
            }
        }
    }
}
