import Foundation
import HearthDomain

/// What an error banner shows. The presenter decides what retrying does.
struct ErrorViewConfiguration: Hashable {
    let title: String
    let message: String
    let retryActionLabel: String?

    init(title: String = Strings.errorTitle, message: String, retryActionLabel: String? = Strings.retry) {
        self.title = title
        self.message = message
        self.retryActionLabel = retryActionLabel
    }

    init(from error: any Error) {
        switch error {
        case let chatError as ChatError:
            self.init(from: chatError)
        case SpeechError.serverNotConfigured:
            self.init(message: Strings.errorSpeechNotConfigured, retryActionLabel: nil)
        case is URLError:
            self.init(message: Strings.errorUnreachable)
        default:
            self.init(message: error.localizedDescription)
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
