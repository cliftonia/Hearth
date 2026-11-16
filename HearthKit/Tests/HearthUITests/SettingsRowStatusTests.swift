import Foundation
import HearthDomain
@testable import HearthUI
import Testing

/// What each row of the main settings list says about the page it leads to, and what VoiceOver reads for it.
@MainActor
struct SettingsRowStatusTests {
    typealias Fixture = SettingsPresenterTests.Fixture

    @Test func `memory says whether it is on and how much is saved`() async {
        let fixture = Fixture()
        let subject = fixture.makeTestSubject()
        await subject.loadAction()
        await fixture.memoryStore.apply(.save("Lives in Brisbane"), isFromUser: true)
        await fixture.memoryStore.apply(.save("Has a dog called Rex"), isFromUser: true)

        #expect(subject.memoryStatus == "On · 2 saved")
        subject.viewModel.isMemoryEnabled = false
        #expect(subject.memoryStatus == "Off")
    }

    @Test(arguments: [(true, "Reads full pages"), (false, "Snippets only")])
    func `web search says whether whole pages are read`(isReading: Bool, status: String) async {
        let subject = Fixture().makeTestSubject()
        await subject.loadAction()

        subject.viewModel.isPageReadingEnabled = isReading

        #expect(subject.webSearchStatus == status)
    }

    @Test func `voice names the voice, says whether replies are read aloud, and needs a speech server`() async {
        let subject = Fixture().makeTestSubject()
        await subject.loadAction()
        #expect(subject.voiceStatus == "Needs a speech server")
        #expect(!subject.hasSpeechServer)

        subject.viewModel.speechAddress = "https://speech.example"
        subject.viewModel.voice = "af_bella"
        #expect(subject.voiceStatus == "af_bella")
        subject.viewModel.isAutoReadEnabled = true
        #expect(subject.voiceStatus == "af_bella · reads aloud")
    }

    @Test func `pictures name the chosen model, or Automatic`() async {
        let subject = Fixture().makeTestSubject()
        await subject.loadAction()
        #expect(subject.picturesStatus == "Automatic")

        subject.viewModel.imageModel = .krea2Turbo
        #expect(subject.picturesStatus == ImageModelKind.krea2Turbo.title)
    }

    @Test(arguments: [
        (true, true, "Replies, Scheduled tasks"),
        (true, false, "Replies"),
        (false, true, "Scheduled tasks"),
        (false, false, "Off")
    ])
    func `notifications name the switches that are on`(replies: Bool, tasks: Bool, status: String) async {
        let subject = Fixture().makeTestSubject()
        await subject.loadAction()

        subject.viewModel.isReplyNotificationsEnabled = replies
        subject.viewModel.isTaskNotificationsEnabled = tasks

        #expect(subject.notificationsStatus == status)
    }

    @Test func `servers say whether the chat server answered, and count its models in the right number`() async throws {
        let fixture = Fixture()
        let subject = fixture.makeTestSubject()
        await subject.loadAction()
        #expect(subject.serversStatus == "Not checked")

        try await fixture.modelStore.refresh(settings: ServerSettings(ollamaAddress: "https://a.example"))
        #expect(subject.serversStatus == "Connected · 1 model")

        fixture.modelCount = 14
        await subject.testAction()
        #expect(subject.serversStatus == "Connected · 14 models")
    }

    @Test func `sync says whether it is on and when it last synced`() async {
        let fixture = Fixture()
        let subject = fixture.makeTestSubject()
        await subject.loadAction()
        #expect(subject.syncRowStatus == "Off")

        fixture.syncStore.update(SyncSettings(hubAddress: "https://hub.example:8765", isEnabled: true))
        #expect(subject.syncRowStatus == "On")

        let now = fixture.now
        fixture.syncStore.updateJournal { $0.lastSyncedAt = now.addingTimeInterval(-120) }
        #expect(subject.syncRowStatus.hasPrefix("On · synced "))
        #expect(subject.syncRowStatus.contains("2"))
    }

    @Test func `VoiceOver reads a row's title and status as one, with the dots as pauses`() {
        let label = SettingsPresenter.accessibilityLabel(title: "Memory", status: "On · 12 saved")

        #expect(label == "Memory, On, 12 saved")
    }
}
