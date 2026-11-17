import UIKit

/// Pictures decoded from their data once and kept, so that a view drawn again, as each word of a reply streams in,
/// does not decode the same picture again.
@MainActor
enum DecodedImages {
    /// The most pictures kept at once; the system may let go of them sooner when memory is short.
    private static let countLimit = 64
    private static let cache: NSCache<NSData, UIImage> = {
        let cache = NSCache<NSData, UIImage>()
        cache.countLimit = countLimit
        return cache
    }()

    /// The picture in the data, decoded and ready to draw, or `nil` if the data is not a picture.
    static func image(from data: Data) -> UIImage? {
        let key = data as NSData
        if let image = cache.object(forKey: key) {
            return image
        }
        guard let image = UIImage(data: data) else {
            return nil
        }
        // Decoding now, once, spares the decode each time the picture is drawn.
        let prepared = image.preparingForDisplay() ?? image
        cache.setObject(prepared, forKey: key)
        return prepared
    }
}
