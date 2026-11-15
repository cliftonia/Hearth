import Foundation
import HearthDomain
@testable import HearthUI

/// The camera as a test sees it: what the user answers, what the camera does, and what was asked of it.
@MainActor
final class CameraFixture {
    /// What a camera that will not work throws.
    struct Broken: Error {}

    /// What the user answers when the system asks them.
    var allowsWhenAsked = true
    var startFails = false
    /// The picture the camera hands over; `nil` for a camera that hands over none.
    var frame: Data? = Data("frame".utf8)
    var availability = CameraAvailability(hasCamera: true, canFlip: true)
    /// Run while the user is being asked, and while the camera is starting, to act in the middle of turning it on.
    var whileAsking: (@MainActor () async -> Void)?
    var whileStarting: (@MainActor () async -> Void)?

    private(set) var requestCount = 0
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var captureCount = 0
    private(set) var flipCount = 0
    private(set) var isRunning = false
    private(set) var position = CameraPositionKind.back

    var provider: CameraProvider {
        let availability = availability
        return CameraProvider(
            requestAuthorization: { await self.answerRequest() },
            start: { try await self.start(facing: $0) },
            stop: { await self.stop() },
            flip: { await self.flip() },
            captureFrame: { try await self.capture() },
            availability: { availability }
        )
    }

    private func answerRequest() async -> Bool {
        requestCount += 1
        await whileAsking?()
        return allowsWhenAsked
    }

    private func start(facing position: CameraPositionKind) async throws {
        startCount += 1
        await whileStarting?()
        if startFails {
            throw Broken()
        }
        self.position = position
        isRunning = true
    }

    private func stop() {
        stopCount += 1
        isRunning = false
    }

    private func flip() -> CameraPositionKind {
        flipCount += 1
        position = position.flipped
        return position
    }

    private func capture() throws -> Data {
        captureCount += 1
        guard isRunning, let frame else {
            throw Broken()
        }
        return frame
    }
}

/// A listener that hears what a test says, one spoken turn at a time.
@MainActor
final class DictationFixture {
    /// Said before anybody was listening, and heard as soon as somebody is.
    private var waiting: [String] = []
    private var listening: AsyncStream<DictationUpdate>.Continuation?

    var provider: DictationProvider {
        DictationProvider(requestAuthorization: { true }, start: { await self.start() }, stop: { await self.stop() })
    }

    /// Speaks one turn and pauses.
    func say(_ words: String) {
        guard let listening else {
            waiting.append(words)
            return
        }
        self.listening = nil
        listening.yield(DictationUpdate(text: words, isFinal: true))
        listening.finish()
    }

    private func start() -> AsyncStream<DictationUpdate> {
        stop()
        let (stream, continuation) = AsyncStream.makeStream(of: DictationUpdate.self)
        if waiting.isEmpty {
            listening = continuation
        } else {
            continuation.yield(DictationUpdate(text: waiting.removeFirst(), isFinal: true))
            continuation.finish()
        }
        return stream
    }

    private func stop() {
        listening?.finish()
        listening = nil
    }
}

/// A voice conversation with a scripted listener, a camera that does as it is told, and a chat that records each turn.
@MainActor
final class VoiceFixture {
    /// One spoken turn as the chat received it.
    struct Turn: Equatable {
        let words: String
        let frameJPEG: Data?
    }

    let camera = CameraFixture()
    let dictation = DictationFixture()
    var modelCanSee = true
    /// Stands in for the shrinking an attached photo is given, marking the picture so a test can tell it was done.
    var prepareFrame: @MainActor (Data) -> Data? = { Data("prepared ".utf8) + $0 }

    private let turns: AsyncStream<Turn>
    private let turnContinuation: AsyncStream<Turn>.Continuation

    init() {
        (turns, turnContinuation) = AsyncStream.makeStream(of: Turn.self)
    }

    /// The picture a turn carries when the camera handed one over and it was prepared.
    var preparedFrame: Data {
        Data("prepared frame".utf8)
    }

    func makeTestSubject() -> VoicePresenter {
        VoicePresenter(dependencies: VoicePresenter.Dependencies(
            dictation: dictation.provider,
            speech: PresenterFixtures.speech,
            camera: camera.provider,
            settings: { ServerSettings() },
            modelName: { "vision" },
            modelCanSee: { self.modelCanSee },
            prepareFrame: { self.prepareFrame($0) },
            runTurn: { words, frameJPEG, _ in self.turnContinuation.yield(Turn(words: words, frameJPEG: frameJPEG)) },
            stopTurn: {}
        ))
    }

    /// Waits for the next spoken turn to reach the chat.
    func nextTurn() async -> Turn? {
        var iterator = turns.makeAsyncIterator()
        return await iterator.next()
    }
}
