import Foundation
@testable import HearthDomain
import Testing

/// A hub's token is only ever kept for the hub it was saved for.
@MainActor
struct SyncStoreTokenTests {
    struct KeychainBusy: Error {}

    /// A store whose token is kept in memory, as the Keychain would keep it, and can be made to fail to forget it.
    struct Fixture {
        let token = Box<String?>("secret")
        let forgetFails = Box(false)

        @MainActor func makeTestSubject() -> SyncStore {
            let settings = try? JSONEncoder().encode(SyncSettings(hubAddress: "https://hub.example", isEnabled: true))
            let (token, forgetFails) = (token, forgetFails)
            return SyncStore(provider: SyncStoreProvider(
                loadSettings: { settings },
                saveSettings: { _ in },
                loadJournal: { nil },
                saveJournal: { _ in },
                readToken: { token.value },
                writeToken: { newToken in
                    if newToken == nil, forgetFails.value {
                        throw KeychainBusy()
                    }
                    token.value = newToken
                }
            ))
        }
    }

    @Test func `the same hub written another way keeps its token`() {
        let fixture = Fixture()
        let subject = fixture.makeTestSubject()

        subject.update(SyncSettings(hubAddress: "hub.example", isEnabled: false))

        #expect(fixture.token.value == "secret")
        #expect(subject.hasToken)
        #expect(subject.token() == "secret")
    }

    @Test(arguments: ["https://other.example", "https://hub.example:8443", "", "not an address"])
    func `pointing at another hub, or at none, forgets the token saved for the last`(address: String) {
        let fixture = Fixture()
        let subject = fixture.makeTestSubject()

        subject.update(SyncSettings(hubAddress: address, isEnabled: false))

        #expect(fixture.token.value == nil)
        #expect(!subject.hasToken)
        #expect(subject.token() == nil)
    }

    @Test func `a token saved after the hub changed is kept for the new hub`() throws {
        let fixture = Fixture()
        let subject = fixture.makeTestSubject()

        subject.update(SyncSettings(hubAddress: "https://other.example", isEnabled: true))
        try subject.setToken("for-the-other-hub")

        #expect(subject.token() == "for-the-other-hub")
        #expect(subject.hasToken)
    }

    @Test func `a token that cannot be forgotten is still shown as saved`() {
        let fixture = Fixture()
        let subject = fixture.makeTestSubject()
        fixture.forgetFails.value = true

        subject.update(SyncSettings(hubAddress: "https://other.example", isEnabled: true))

        #expect(subject.hasToken)
        #expect(subject.settings.hubAddress == "https://other.example")
    }
}
