import PhotosUI
import SwiftUI
import UIKit

/// Loads picked photos and shrinks them to a size a vision model reads comfortably.
enum PhotoLoader {
    private static let maximumSideLength: CGFloat = 1280

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
