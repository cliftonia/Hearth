import Foundation
import HearthData

extension ChatError {
    /// Gives transport and server failures a domain meaning; anything else passes through untouched.
    static func remapping(_ error: any Error) -> any Error {
        switch error {
        case HTTPError.server(let message):
            ChatError.server(message: message)
        case HTTPError.status(let code, let body):
            ChatError.server(message: body.isEmpty ? "HTTP \(code)" : "HTTP \(code): \(body)")
        case HTTPError.invalidResponse:
            ChatError.unreachable
        case let urlError as URLError where urlError.code != .cancelled:
            ChatError.unreachable
        default:
            error
        }
    }
}
