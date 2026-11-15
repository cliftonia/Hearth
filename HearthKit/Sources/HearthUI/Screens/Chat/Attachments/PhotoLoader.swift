import PhotosUI
import SwiftUI
import UIKit

/// Loads picked photos and shrinks them to a size a vision model reads comfortably.
enum PhotoLoader {
    /// The longest side of a photo once shrunk, in pixels.
    private static let maximumSideLength: CGFloat = 1280
    /// The side of the square a profile photo is kept as, in pixels: enough for the avatar at its largest.
    private static let avatarSideLength: CGFloat = 320

    /// The picked photos as JPEG data, in the order they were picked.
    static func jpegData(from items: [PhotosPickerItem]) async -> [Data] {
        var result: [Data] = []
        for item in items {
            // A photo that cannot be loaded is left out; the rest are still attached.
            if let data = try? await item.loadTransferable(type: Data.self), let jpeg = downscaledJPEG(from: data) {
                result.append(jpeg)
            }
        }
        return result
    }

    /// A picked photo made into a small square for the profile, cut from its middle; `nil` if it cannot be read.
    static func avatarJPEG(from item: PhotosPickerItem) async -> Data? {
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            return nil
        }
        return squareJPEG(from: data, sideLength: avatarSideLength)
    }

    /// Re-encodes the middle of a photo as a square of the given side in pixels, or returns `nil` if the data is not an image.
    static func squareJPEG(from data: Data, sideLength: CGFloat) -> Data? {
        guard let image = UIImage(data: data), image.size.width > 0, image.size.height > 0 else {
            return nil
        }
        // The shorter side fills the square and the longer one overhangs it equally at both ends.
        let scale = sideLength / min(image.size.width, image.size.height)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let origin = CGPoint(x: (sideLength - size.width) / 2, y: (sideLength - size.height) / 2)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: sideLength, height: sideLength), format: format)
            .image { _ in image.draw(in: CGRect(origin: origin, size: size)) }
            .jpegData(compressionQuality: 0.8)
    }

    /// Re-encodes a photo no larger than the maximum side, or returns `nil` if the data is not an image.
    static func downscaledJPEG(from data: Data) -> Data? {
        guard let image = UIImage(data: data) else {
            return nil
        }
        let scale = min(1, maximumSideLength / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format)
            .image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
            .jpegData(compressionQuality: 0.75)
    }
}
