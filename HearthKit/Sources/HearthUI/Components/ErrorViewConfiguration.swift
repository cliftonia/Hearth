import Foundation
import HearthDomain

/// What an error banner shows. The presenter decides what retrying does.
struct ErrorViewConfiguration: Hashable {
    let title: String
    let message: String
    /// The retry button's title, or `nil` when trying again would not help.
    let retryActionLabel: String?

    init(title: String = Strings.errorTitle, message: String, retryActionLabel: String? = Strings.retry) {
        self.title = title
        self.message = message
        self.retryActionLabel = retryActionLabel
    }

    /// Words the user can act on for an error from any layer. An error that only a change of settings can fix offers no retry.
    init(from error: any Error) {
        switch error {
        case let chatError as ChatError:
            self.init(from: chatError)
        case SpeechError.serverNotConfigured:
            self.init(message: Strings.errorSpeechNotConfigured, retryActionLabel: nil)
        case let imageError as ImageError:
            self.init(from: imageError)
        case is URLError:
            self.init(message: Strings.errorUnreachable)
        default:
            self.init(message: error.localizedDescription)
        }
    }

    private init(from error: ImageError) {
        switch error {
        case .serverNotConfigured:
            self.init(title: Strings.picture, message: Strings.errorPictureNotConfigured, retryActionLabel: nil)
        case .noModel:
            self.init(title: Strings.picture, message: Strings.errorPictureNoModel, retryActionLabel: nil)
        case .cannotEdit:
            self.init(title: Strings.picture, message: Strings.errorPictureCannotChange, retryActionLabel: nil)
        case .cannotEnlarge:
            self.init(title: Strings.picture, message: Strings.errorPictureCannotEnlarge, retryActionLabel: nil)
        case .failed(let message):
            self.init(title: Strings.picture, message: message.isEmpty ? Strings.errorPictureFailed : message)
        case .timedOut:
            self.init(title: Strings.picture, message: Strings.errorPictureTimedOut)
        }
    }

    private init(from error: ChatError) {
        switch error {
        case .serverNotConfigured:
            self.init(message: Strings.errorServerNotConfigured, retryActionLabel: nil)
        case .noModelSelected:
            self.init(message: Strings.errorNoModel, retryActionLabel: nil)
        case .unreachable:
            self.init(message: Strings.errorUnreachable)
        case .server(let message):
            self.init(message: message)
        }
    }
}
