import SwiftUI
import UIKit

/// A row of photo thumbnails, optionally removable.
struct PhotoStrip: View {
    /// A decoded photo and its position among the attachments.
    private struct Photo: Identifiable {
        let id: Int
        let image: UIImage
    }

    let imagesJPEG: [Data]
    let sideLength: CGFloat
    /// Called with a photo's position when its remove button is tapped. Without it the photos cannot be removed.
    let removeAction: ((Int) -> Void)?

    var body: some View {
        HStack(spacing: HearthSpacing.s8) {
            ForEach(photos) { photo in
                Image(uiImage: photo.image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: sideLength, height: sideLength)
                    .clipShape(RoundedRectangle(cornerRadius: HearthRadius.card, style: .continuous))
                    .accessibilityLabel(Strings.attachedPhoto)
                    .overlay(alignment: .topTrailing) {
                        if let removeAction {
                            Button(action: { removeAction(photo.id) }, label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.body)
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(HearthColor.onPine, HearthColor.ink.opacity(0.7))
                                    .padding(HearthSpacing.s4)
                            })
                            .buttonStyle(.plain)
                            .accessibilityLabel(Strings.removePhoto)
                        }
                    }
            }
        }
    }

    /// The photos that can be decoded, each remembering its position among the attachments.
    private var photos: [Photo] {
        imagesJPEG.enumerated().compactMap { index, data in
            UIImage(data: data).map { Photo(id: index, image: $0) }
        }
    }
}
