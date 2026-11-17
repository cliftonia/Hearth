import Foundation
import HearthDomain
@testable import HearthUI
import Testing
import UIKit

/// What becomes of the picture a voice conversation takes: how it is shrunk, kept in the chat and sent to the model.
@MainActor
struct VoicePictureTests {
    /// Keeps what the model was last sent, safely across tasks.
    final class Sent: @unchecked Sendable {
        private let lock = NSLock()
        private var request: ChatRequest?

        var value: ChatRequest? { lock.withLock { request } }

        func keep(_ request: ChatRequest) {
            lock.withLock { self.request = request }
        }
    }

    /// The chat presenter with a model that can see and answers in one piece.
    @MainActor
    final class Fixture {
        let sent = Sent()
        let conversationStore = PresenterFixtures.conversationStore()

        func makeTestSubject() -> ChatPresenter {
            let sent = sent
            let provider = ChatDataProvider(
                fetchModels: { _ in [] },
                streamChat: { _, request in
                    sent.keep(request)
                    return AsyncThrowingStream { continuation in
                        continuation.yield(.text("A mug."))
                        continuation.finish()
                    }
                },
                complete: { _, _ in "" }
            )
            let settings = ServerSettings(ollamaAddress: "https://ollama.example", isFollowUpsEnabled: false)
            let subject = ChatPresenter(dependencies: ChatPresenter.Dependencies(
                chat: ChatInteractor(chat: provider, search: SearchDataProvider { _, _ in [] }),
                speech: PresenterFixtures.speech,
                image: PresenterFixtures.image,
                research: PresenterFixtures.research,
                dictation: PresenterFixtures.dictation,
                notifications: NotificationsFixture().provider,
                photoLibrary: PresenterFixtures.photoLibrary,
                settingsStore: PresenterFixtures.settingsStore(settings),
                modelStore: ModelStore(fetchModels: { _ in [] }),
                conversationStore: conversationStore,
                memoryStore: PresenterFixtures.memoryStore(),
                projectStore: PresenterFixtures.projectStore(),
                isLocked: { false },
                isOnScreen: { true },
                announce: { _ in },
                isVoiceOverRunning: { false }
            ))
            subject.viewModel.selectedModel = ChatModel(id: ChatModel.ID("vision"), isCloud: true, canSee: true)
            return subject
        }
    }

    private let frame = Data("frame".utf8)

    @Test(arguments: [false, true])
    func `a spoken turn's picture is kept on the user's message, sent to the model and saved with the chat`(isPrivate: Bool) async {
        let fixture = Fixture()
        let subject = fixture.makeTestSubject()
        if isPrivate {
            subject.togglePrivateAction()
        }

        await subject.submit(text: "What is this?", imagesJPEG: [frame], style: .voice) { _ in }

        let messages = subject.viewModel.conversation.messages
        #expect(messages.first?.role == .user)
        #expect(messages.first?.text == "What is this?")
        #expect(messages.first?.imagesJPEG == [frame])
        #expect(messages.last?.text == "A mug.")
        let asked = fixture.sent.value?.messages.last { $0.role == .user }
        #expect(asked?.imagesJPEG == [frame])
        let saved = fixture.conversationStore.conversation(for: subject.viewModel.conversation.id)
        #expect(saved?.messages.first?.imagesJPEG == [frame])
        #expect(saved?.isPrivate == isPrivate)
    }

    @Test func `a spoken turn with no picture is sent as words alone`() async {
        let fixture = Fixture()
        let subject = fixture.makeTestSubject()

        await subject.submit(text: "Hello.", style: .voice) { _ in }

        #expect(subject.viewModel.conversation.messages.first?.imagesJPEG.isEmpty == true)
        #expect(fixture.sent.value?.messages.last { $0.role == .user }?.imagesJPEG.isEmpty == true)
    }

    @Test(arguments: [CGSize(width: 4000, height: 3000), CGSize(width: 1080, height: 1920), CGSize(width: 640, height: 480)])
    func `a picture is shrunk to the bounds an attached photo is held to, and never enlarged`(size: CGSize) throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let original = UIGraphicsImageRenderer(size: size, format: format)
            .image { context in context.fill(CGRect(origin: .zero, size: size)) }
            .jpegData(compressionQuality: 0.9)

        let photo = try #require(original)
        let prepared = try #require(PhotoLoader.downscaledJPEG(from: photo))
        let image = try #require(UIImage(data: prepared))

        let longest = max(image.size.width, image.size.height) * image.scale
        #expect(longest == min(1280, max(size.width, size.height)))
        #expect(abs(image.size.width / image.size.height - size.width / size.height) < 0.01)
    }

    @Test func `what is not a picture is not prepared at all`() {
        #expect(PhotoLoader.downscaledJPEG(from: Data("not a picture".utf8)) == nil)
    }
}
