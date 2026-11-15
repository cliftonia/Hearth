import Foundation
import HearthDomain
@testable import HearthUI
import Testing

/// The sync page: the address, the token, the switch, and the status line.
@MainActor
struct SyncSettingsTests {
    @Test func `a built-in hub address fills the page until one is saved, and leaves sync off`() {
        let fresh = SyncStore(provider: Self.provider(saved: nil), defaultHubAddress: "https://hub.example:8765")
        let saved = SyncStore(
            provider: Self.provider(saved: SyncSettings(hubAddress: "https://other.example:8765")),
            defaultHubAddress: "https://hub.example:8765"
        )

        #expect(fresh.settings.hubAddress == "https://hub.example:8765")
        #expect(!fresh.settings.isEnabled)
        #expect(saved.settings.hubAddress == "https://other.example:8765")
    }

    private static func provider(saved: SyncSettings?) -> SyncStoreProvider {
        let data = saved.flatMap { try? JSONEncoder().encode($0) }
        return SyncStoreProvider(
            loadSettings: { data },
            saveSettings: { _ in },
            loadJournal: { nil },
            saveJournal: { _ in },
            readToken: { nil },
            writeToken: { _ in }
        )
    }

    @Test func `without a usable address the switch cannot be turned on`() async {
        let fixture = SettingsPresenterTests.Fixture()
        let subject = fixture.makeTestSubject()
        await subject.loadAction()

        #expect(!subject.canEnableSync)
        subject.viewModel.isSyncEnabled = true
        await subject.syncEnabledAction()

        #expect(!fixture.syncStore.settings.isEnabled)
        #expect(!subject.viewModel.isSyncEnabled)
        #expect(fixture.syncNowCount == 0)
    }

    @Test func `turning sync on keeps the address and syncs at once`() async {
        let fixture = SettingsPresenterTests.Fixture()
        let subject = fixture.makeTestSubject()
        await subject.loadAction()

        subject.viewModel.syncAddress = " http://hub.local:8765 "
        subject.viewModel.isSyncEnabled = true
        await subject.syncEnabledAction()

        #expect(fixture.syncStore.settings == SyncSettings(hubAddress: "http://hub.local:8765", isEnabled: true))
        #expect(fixture.syncNowCount == 1)
    }

    @Test func `clearing the address turns sync off`() async {
        let fixture = SettingsPresenterTests.Fixture()
        fixture.syncStore.update(SyncSettings(hubAddress: "http://hub.local:8765", isEnabled: true))
        let subject = fixture.makeTestSubject()
        await subject.loadAction()

        subject.viewModel.syncAddress = ""
        subject.syncAddressAction()

        #expect(fixture.syncStore.settings == SyncSettings())
    }

    @Test func `a token goes to the store and never stays in the form`() async {
        let fixture = SettingsPresenterTests.Fixture()
        let subject = fixture.makeTestSubject()
        await subject.loadAction()

        subject.viewModel.syncTokenDraft = "  throwaway-value  "
        subject.saveSyncTokenAction()
        #expect(fixture.syncStore.token() == "throwaway-value")
        #expect(fixture.syncStore.hasToken)
        #expect(subject.viewModel.syncTokenDraft.isEmpty)

        await subject.loadAction()
        #expect(subject.viewModel.syncTokenDraft.isEmpty)
        subject.removeSyncTokenAction()
        #expect(!fixture.syncStore.hasToken)
    }

    @Test func `a check of the hub says what it found in plain words`() async {
        let fixture = SettingsPresenterTests.Fixture()
        let subject = fixture.makeTestSubject()
        await subject.loadAction()
        subject.viewModel.syncAddress = "http://hub.local:8765"

        await subject.checkHubAction()
        #expect(subject.viewModel.syncCheck == .succeeded)

        fixture.checkAnswer = .failed(.tokenNeeded)
        await subject.checkHubAction()
        #expect(subject.viewModel.syncCheck == .failed(message: Strings.syncFailedTokenNeeded))
    }

    @Test func `the status line says when it last synced, or what went wrong`() {
        let fixture = SettingsPresenterTests.Fixture()
        let subject = fixture.makeTestSubject()
        #expect(subject.syncStatusText == Strings.syncNever)

        fixture.syncStore.syncDidEnd(failure: .unreachable, finished: false)
        #expect(subject.syncStatusText == Strings.syncFailedUnreachable)

        fixture.syncStore.syncDidEnd(failure: nil, finished: true)
        #expect(subject.syncStatusText.hasPrefix("Last synced"))

        fixture.syncStore.syncDidEnd(failure: .tooLarge(count: 2), finished: true)
        #expect(subject.syncStatusText == Strings.syncTooLarge(number: 2))
    }
}
