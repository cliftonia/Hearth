import Foundation
import HearthData

/// Why a picture could not be added to the photo library.
public enum PhotoLibraryErrorKind: Error, Sendable, Equatable {
    /// The user has not given leave to add to the library; only the Settings app can change that now.
    case notAllowed
    /// The library could not take the picture.
    case failed
}

/// How the domain keeps a picture in the user's photo library.
public struct PhotoLibraryProvider: Sendable {
    /// Adds the picture, given as image data, to the library. Throws a `PhotoLibraryErrorKind` if it cannot.
    public let savePicture: @Sendable (Data) async throws -> Void

    public init(savePicture: @escaping @Sendable (Data) async throws -> Void) {
        self.savePicture = savePicture
    }
}

public extension PhotoLibraryProvider {
    /// The device's photo library.
    static func live(service: PhotoLibraryService = PhotoLibraryService()) -> PhotoLibraryProvider {
        PhotoLibraryProvider { imageData in
            do {
                try await service.add(imageData: imageData)
            } catch PhotoLibraryService.PhotoLibraryError.notAllowed {
                throw PhotoLibraryErrorKind.notAllowed
            } catch {
                throw PhotoLibraryErrorKind.failed
            }
        }
    }
}
