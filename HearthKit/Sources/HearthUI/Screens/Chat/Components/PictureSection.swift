import SwiftUI
import UIKit

/// A picture the app made, shown in a reply, with ways to keep it: save to Photos, share, or copy.
struct PictureSection: View {
    /// The widest a picture is shown, so that it sits in the column like the text around it.
    private static let maximumSide: CGFloat = 420

    let pictureJPEG: Data

    @State private var savedCount = 0

    var body: some View {
        if let image = UIImage(data: pictureJPEG) {
            VStack(alignment: .leading, spacing: HearthSpacing.s8) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: Self.maximumSide, maxHeight: Self.maximumSide, alignment: .leading)
                    .clipShape(RoundedRectangle(cornerRadius: HearthRadius.card, style: .continuous))
                    .accessibilityLabel(Strings.picture)
                    .contextMenu { menu(for: image) }
                HStack(spacing: HearthSpacing.s4) {
                    Button(action: { save(image) }, label: {
                        Label(Strings.pictureSave, systemImage: "square.and.arrow.down")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(HearthColor.ink)
                            .padding(.horizontal, HearthSpacing.s12)
                            .padding(.vertical, HearthSpacing.s6)
                            .capsuleOutline()
                    })
                    .buttonStyle(.plain)
                    ShareLink(item: Image(uiImage: image), preview: SharePreview(Strings.picture, image: Image(uiImage: image))) {
                        Label(Strings.share, systemImage: "square.and.arrow.up")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(HearthColor.ink)
                            .padding(.horizontal, HearthSpacing.s12)
                            .padding(.vertical, HearthSpacing.s6)
                            .capsuleOutline()
                    }
                    .buttonStyle(.plain)
                }
            }
            .sensoryFeedback(.success, trigger: savedCount)
        }
    }

    @ViewBuilder
    private func menu(for image: UIImage) -> some View {
        Button(action: { save(image) }, label: {
            Label(Strings.pictureSave, systemImage: "square.and.arrow.down")
        })
        Button(action: { UIPasteboard.general.image = image }, label: {
            Label(Strings.copy, systemImage: "doc.on.doc")
        })
    }

    /// Adds the picture to the photo library. iOS asks for leave the first time.
    private func save(_ image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        savedCount += 1
    }
}
