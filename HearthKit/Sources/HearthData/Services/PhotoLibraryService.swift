import Foundation
import Photos

/// Adds pictures to the photo library, asking only for leave to add, never to read.
public struct PhotoLibraryService: Sendable {
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
}
