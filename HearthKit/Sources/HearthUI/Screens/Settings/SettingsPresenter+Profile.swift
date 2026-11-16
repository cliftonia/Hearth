import Foundation
import HearthDomain

// The profile page's photo, and erasing everything on the device from the foot of the main list.
extension SettingsPresenter {
    /// The profile photo as JPEG data; `nil` when none has been chosen.
    var photoJPEG: Data? { dependencies.profileStore.photoJPEG }

    /// Reads the photo from disk as the settings open. Without it the avatar shows initials.
    func loadProfilePhoto() async {
        do {
            try await dependencies.profileStore.load()
        } catch {
            logger.error("Loading the profile photo failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Keeps the chosen photo, already made small.
    ///
    /// - Parameter jpeg: The photo, or `nil` when what was chosen could not be read as a picture.
    func setPhotoAction(_ jpeg: Data?) async {
        viewModel.profileError = nil
        guard let jpeg else {
            viewModel.profileError = Strings.profilePhotoFailed
            return
        }
        do {
            try await dependencies.profileStore.setPhoto(jpeg)
        } catch {
            logger.error("Saving the profile photo failed: \(error.localizedDescription, privacy: .public)")
            viewModel.profileError = Strings.profilePhotoFailed
        }
    }

    /// Goes back to showing initials.
    func removePhotoAction() async {
        viewModel.profileError = nil
        do {
            try await dependencies.profileStore.removePhoto()
        } catch {
            logger.error("Removing the profile photo failed: \(error.localizedDescription, privacy: .public)")
            viewModel.profileError = Strings.profilePhotoFailed
        }
    }

    /// Erases everything on the device, once the user has confirmed, and tells the coordinator to start afresh.
    /// If something could not be erased the settings stay open and say so.
    func eraseAction() async {
        viewModel.eraseError = nil
        await stopVoicePreviewAction()
        await dependencies.quietChat()
        do {
            try await dependencies.eraser.eraseAll()
            // The screen still shows what was erased, and closing keeps what the screen shows.
            fillFromSaved()
            delegate?.settingsPresenterDidErase(self)
        } catch {
            logger.error("Erasing everything failed: \(error.localizedDescription, privacy: .public)")
            viewModel.eraseError = Strings.eraseAllFailed
        }
    }
}
