import Foundation
import Photos
import UIKit

/// Adds pictures to the photo library, and shows the latest photos in it so that one can be added to a message.
/// Adding asks only for leave to add; the latest photos are shown only with leave to read, asked for when they are
/// first wanted, and nothing is read without it.
public struct PhotoLibraryService: Sendable {
    /// One of the latest photos: the library's name for it, and a small copy to show.
    public struct RecentPhoto: Sendable {
        public let identifier: String
        public let thumbnailJPEG: Data
    }

    /// What can go wrong adding a picture.
    public enum PhotoLibraryError: Error, Sendable, Equatable {
        /// The user has not given leave to add to the library.
        case notAllowed
    }

    public init() {}

    /// Adds the picture, as a new photo. The system asks for leave the first time; if it is refused, or the library
    /// cannot take the picture, this throws.
    public func add(imageData: Data) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw PhotoLibraryError.notAllowed
        }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetCreationRequest.forAsset().addResource(with: .photo, data: imageData, options: nil)
        }
    }

    /// The latest photos, newest first, each as a small copy no longer than `side` points on its shorter edge.
    /// The system asks for leave the first time. Without it, or with none of the photos to hand on the device, there
    /// are none; with leave for only some photos, those are the ones shown.
    public func recentPhotos(limit: Int, side: CGFloat) async -> [RecentPhoto] {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard status == .authorized || status == .limited else {
            return []
        }
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = limit
        let assets = PHAsset.fetchAssets(with: .image, options: options)
        var photos: [RecentPhoto] = []
        for index in 0..<assets.count {
            let asset = assets.object(at: index)
            if let thumbnail = await Self.thumbnail(of: asset, side: side) {
                photos.append(RecentPhoto(identifier: asset.localIdentifier, thumbnailJPEG: thumbnail))
            }
        }
        return photos
    }

    /// The photo itself, fetched from iCloud if it is not on the device; `nil` if it cannot be had.
    public func photoData(identifier: String) async -> Data? {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject else {
            return nil
        }
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
                continuation.resume(returning: data)
            }
        }
    }

    /// A small copy of a photo that is on the device. One kept only in iCloud is passed over rather than fetched
    /// just to be glanced at.
    private static func thumbnail(of asset: PHAsset, side: CGFloat) async -> Data? {
        let options = PHImageRequestOptions()
        // One answer, at the size asked for, so that the continuation is resumed exactly once.
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = false
        let scale: CGFloat = 3
        let size = CGSize(width: side * scale, height: side * scale)
        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(for: asset, targetSize: size, contentMode: .aspectFill, options: options) { image, _ in
                continuation.resume(returning: image?.jpegData(compressionQuality: 0.8))
            }
        }
    }
}
