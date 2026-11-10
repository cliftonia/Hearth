import Foundation
import HearthData

public struct AuthenticationProvider: Sendable {
    /// Shows the given reason and returns whether the phone's owner proved who they are.
    public let authenticate: @Sendable (String) async -> Bool

    public init(authenticate: @escaping @Sendable (String) async -> Bool) {
        self.authenticate = authenticate
    }
}

public extension AuthenticationProvider {
    static func live(service: AuthenticationService = AuthenticationService()) -> AuthenticationProvider {
        AuthenticationProvider { reason in
            await service.authenticate(reason: reason)
        }
    }
}
