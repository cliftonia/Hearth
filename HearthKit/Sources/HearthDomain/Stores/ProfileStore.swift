import Foundation
import Observation

/// The user's profile photo, shared by the settings and the profile page. Their names are settings like any other.
@MainActor
@Observable
public final class ProfileStore {
    /// The photo as JPEG data; `nil` when the user has not chosen one.
    public private(set) var photoJPEG: Data?

    private let provider: ProfilePhotoProvider

    public init(provider: ProfilePhotoProvider) {
        self.provider = provider
    }

    public func load() async throws {
        photoJPEG = try await provider.load()
    }

    /// Keeps a new photo. If it cannot be written the old one stays, and the error is passed on.
    public func setPhoto(_ jpeg: Data) async throws {
        let before = photoJPEG
        photoJPEG = jpeg
        do {
            try await provider.save(jpeg)
        } catch {
            photoJPEG = before
            throw error
        }
    }

    /// Removes the photo. If it cannot be removed from disk it stays, and the error is passed on.
    public func removePhoto() async throws {
        let before = photoJPEG
        photoJPEG = nil
        do {
            try await provider.delete()
        } catch {
            photoJPEG = before
            throw error
        }
    }
}
