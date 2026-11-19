import Foundation
import HearthCore
import HearthData

/// One of the latest photos in the user's library, as it is offered for adding to a message.
public struct RecentPhoto: Identifiable, Hashable, Sendable {
    public typealias ID = Tagged<RecentPhoto, String>

    public let id: ID
    /// A small copy to show; the photo itself is fetched only when it is chosen.
    public let thumbnailJPEG: Data

    public init(id: ID, thumbnailJPEG: Data) {
        self.id = id
        self.thumbnailJPEG = thumbnailJPEG
    }
}

/// Why a picture could not be added to the photo library.
public enum PhotoLibraryErrorKind: Error, Sendable, Equatable {
    /// The user has not given leave to add to the library; only the Settings app can change that now.
    case notAllowed
    /// The library could not take the picture.
    case failed
}

/// How the domain keeps a picture in the user's photo library, and offers the latest photos in it.
public struct PhotoLibraryProvider: Sendable {
    /// How many of the latest photos are offered.
    public static let recentPhotoCount = 12
    /// The length in points of the side the small copies are made for.
    public static let recentPhotoSide: CGFloat = 96

    /// Adds the picture, given as image data, to the library. Throws a `PhotoLibraryErrorKind` if it cannot.
    public let savePicture: @Sendable (Data) async throws -> Void
    /// The latest photos, newest first; none when the user has not given leave to read the library.
    public let recentPhotos: @Sendable () async -> [RecentPhoto]
    /// One of those photos in full; `nil` if it can no longer be had.
    public let photoData: @Sendable (RecentPhoto.ID) async -> Data?

    public init(
        savePicture: @escaping @Sendable (Data) async throws -> Void,
        recentPhotos: @escaping @Sendable () async -> [RecentPhoto] = { [] },
        photoData: @escaping @Sendable (RecentPhoto.ID) async -> Data? = { _ in nil }
    ) {
        self.savePicture = savePicture
        self.recentPhotos = recentPhotos
        self.photoData = photoData
    }
}

public extension PhotoLibraryProvider {
    /// The device's photo library.
    static func live(service: PhotoLibraryService = PhotoLibraryService()) -> PhotoLibraryProvider {
        PhotoLibraryProvider(
            savePicture: { imageData in
                do {
                    try await service.add(imageData: imageData)
                } catch PhotoLibraryService.PhotoLibraryError.notAllowed {
                    throw PhotoLibraryErrorKind.notAllowed
                } catch {
                    throw PhotoLibraryErrorKind.failed
                }
            },
            recentPhotos: {
                await service.recentPhotos(limit: recentPhotoCount, side: recentPhotoSide).map {
                    RecentPhoto(id: RecentPhoto.ID($0.identifier), thumbnailJPEG: $0.thumbnailJPEG)
                }
            },
            photoData: { await service.photoData(identifier: $0.rawValue) }
        )
    }
}
