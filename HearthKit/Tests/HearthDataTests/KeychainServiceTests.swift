import Foundation
@testable import HearthData
import Security
import Testing

struct KeychainServiceTests {
    /// A test host without the app's keychain entitlement is refused the keychain outright, so the round trip can
    /// only be checked where the keychain answers.
    static let isKeychainReachable: Bool = {
        let probe = KeychainService(service: "Hearth.tests.probe", account: UUID().uuidString)
        defer { try? probe.delete() }
        do {
            try probe.write("probe")
            return true
        } catch let error as KeychainService.KeychainError {
            return error.status != errSecMissingEntitlement
        } catch {
            return true
        }
    }()

    @Test(.enabled(if: isKeychainReachable, "the test host has no keychain entitlement"))
    func `a secret is kept, read back and forgotten`() throws {
        let keychain = KeychainService(service: "Hearth.tests", account: UUID().uuidString)
        defer { try? keychain.delete() }

        try keychain.write("first")
        try keychain.write("second")
        #expect(try keychain.read() == "second")
        try keychain.delete()
        #expect(try keychain.read() == nil)
    }
}
