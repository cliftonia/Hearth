import Foundation
import HearthDomain
@testable import HearthUI
import Testing

/// The servers page and the lock: what is asked of a server and when, what VoiceOver is told, and how the lock is
/// named and turned on.
@MainActor
struct SettingsServersTests {
    typealias Fixture = SettingsPresenterTests.Fixture

    @Test func `a chat server address is acted on once its field is left, not while it is typed`() async {
        let fixture = Fixture()
        let subject = fixture.makeTestSubject()
        await subject.loadAction()

        subject.viewModel.ollamaAddress = "https://b.exam"
        subject.viewModel.ollamaAddress = "https://b.example "
        #expect(fixture.chatServerChangeCount == 0)
        #expect(fixture.settingsStore.settings.ollamaAddress == "https://a.example")

        await subject.serverAddressesEditedAction()
        await subject.serverAddressesEditedAction()

        #expect(fixture.settingsStore.settings.ollamaAddress == "https://b.example")
        #expect(fixture.chatServerChangeCount == 1)
    }

    @Test func `an address kept along with a switch is still acted on when its field is left`() async {
        let fixture = Fixture()
        let subject = fixture.makeTestSubject()
        await subject.loadAction()

        subject.viewModel.ollamaAddress = "https://c.example"
        subject.viewModel.isFollowUpsEnabled = false
        subject.keepAction()
        #expect(fixture.chatServerChangeCount == 0)
        await subject.serverAddressesEditedAction()

        #expect(fixture.chatServerChangeCount == 1)
    }

    @Test func `closing with the same chat server asks for no new models`() async {
        let fixture = Fixture()
        let subject = fixture.makeTestSubject()
        await subject.loadAction()

        subject.viewModel.searchAddress = "https://search.example"
        await subject.closeAction()

        #expect(fixture.settingsStore.settings.searchAddress == "https://search.example")
        #expect(fixture.chatServerChangeCount == 0)
        #expect(fixture.finishCount == 1)
    }

    @Test(arguments: [(1, "Connected. 1 model found."), (14, "Connected. 14 models found.")])
    func `a connection test says how many models were found, in the singular for one, and tells VoiceOver`(count: Int, words: String) async {
        let fixture = Fixture()
        fixture.modelCount = count
        let subject = fixture.makeTestSubject()
        await subject.loadAction()

        await subject.testAction()

        #expect(subject.viewModel.connectionCheck == .succeeded(modelCount: count))
        #expect(fixture.announcements == [words])
    }

    @Test func `a failed connection test is told to VoiceOver`() async {
        let fixture = Fixture()
        fixture.modelCount = nil
        let subject = fixture.makeTestSubject()
        await subject.loadAction()

        await subject.testAction()

        guard case .failed(let message) = subject.viewModel.connectionCheck else {
            Issue.record("The test did not fail")
            return
        }
        #expect(fixture.announcements == [message])
        #expect(subject.serversStatus == Strings.serversNotConnected)
    }

    @Test func `the outcome of a hub check is told to VoiceOver`() async {
        let fixture = Fixture()
        let subject = fixture.makeTestSubject()
        await subject.loadAction()
        subject.viewModel.syncAddress = "https://hub.example:8765"

        await subject.checkHubAction()
        fixture.checkAnswer = .failed(.unreachable)
        await subject.checkHubAction()

        #expect(fixture.announcements == [Strings.syncCheckSucceeded, Strings.syncFailedUnreachable])
    }

    @Test func `the lock's switch is named for the device's biometrics`() async {
        let fixture = Fixture()
        fixture.biometry = .touchID
        let subject = fixture.makeTestSubject()
        await subject.loadAction()

        #expect(subject.viewModel.unlockWording == UnlockWording(biometry: .touchID))
    }

    @Test func `the lock is kept only once the owner has shown they can open it, asked in the device's words`() async {
        let fixture = Fixture()
        fixture.isOwner = false
        let subject = fixture.makeTestSubject()
        await subject.loadAction()

        subject.viewModel.isLockEnabled = true
        await subject.lockAction()
        #expect(!subject.viewModel.isLockEnabled)
        #expect(!fixture.settingsStore.settings.isLockEnabled)

        fixture.isOwner = true
        subject.viewModel.isLockEnabled = true
        await subject.lockAction()
        #expect(fixture.settingsStore.settings.isLockEnabled)
        #expect(fixture.authenticationReasons.count == 2)
        #expect(fixture.authenticationReasons.allSatisfy { $0 == subject.viewModel.unlockWording.enableReason })

        subject.viewModel.isLockEnabled = false
        await subject.lockAction()
        #expect(!fixture.settingsStore.settings.isLockEnabled)
        #expect(fixture.authenticationReasons.count == 2)
    }
}

/// What the lock is called on each kind of device.
struct UnlockWordingTests {
    @Test(arguments: [
        (BiometryKind.faceID, false, "Require Face ID or passcode", "Unlock with Face ID"),
        (.touchID, false, "Require Touch ID or passcode", "Unlock with Touch ID"),
        (.opticID, false, "Require Optic ID or passcode", "Unlock with Optic ID"),
        (.none, false, "Require passcode", "Unlock with passcode"),
        (.touchID, true, "Require Touch ID or password", "Unlock with Touch ID"),
        (.none, true, "Require password", "Unlock with password")
    ])
    func `the lock is named for how the device unlocks`(biometry: BiometryKind, usesPassword: Bool, require: String, unlock: String) {
        let wording = UnlockWording(biometry: biometry, usesPassword: usesPassword)

        #expect(wording.requireTitle == require)
        #expect(wording.unlockTitle == unlock)
    }

    @Test func `the reasons the system shows name the same way of unlocking`() {
        let mac = UnlockWording(biometry: .touchID, usesPassword: true)
        let phone = UnlockWording(biometry: .none, usesPassword: false)

        #expect(mac.unlockReason == "Use Touch ID or your password to unlock your conversations.")
        #expect(phone.enableReason == "Confirm it is you with your passcode to turn on the lock.")
    }
}
