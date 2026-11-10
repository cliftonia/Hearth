import Foundation
import HearthCore
import HearthDomain
import Observation
import os

@MainActor
protocol VoicePresenterDelegate: AnyObject {
    func voicePresenterDidFinish(_ presenter: VoicePresenter)
}

enum VoiceStateKind: Hashable {
    case listening
    case thinking
    case speaking
    case muted
    case unavailable
}

@MainActor
@Observable
final class VoiceViewModel {
    var state: VoiceStateKind = .listening
    var caption = ""
    var modelName = ""
    var voiceName = ""
}

/// Runs a spoken conversation: listen until the user pauses, ask the model, speak the reply, listen again.
@MainActor
final class VoicePresenter {
    struct Dependencies {
        let dictation: DictationProvider
        let speech: SpeechInteractor
        let settings: @MainActor () -> ServerSettings
        let modelName: @MainActor () -> String
        /// Sends the words to the chat; the closure receives the reply piece by piece.
        let runTurn: @MainActor (String, @escaping @MainActor (String) -> Void) async -> Void
        let stopTurn: @MainActor () async -> Void
    }

    private static let pauseBeforeSending: Duration = .milliseconds(1400)

    let viewModel = VoiceViewModel()
    weak var delegate: (any VoicePresenterDelegate)?

    private let dependencies: Dependencies
    private let logger = Logger(for: VoicePresenter.self)
    private var loopTask: Task<Void, Never>?
    private var speakTask: Task<Void, Never>?

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    func startAction() async {
        viewModel.modelName = dependencies.modelName()
        viewModel.voiceName = dependencies.settings().voice
        viewModel.caption = ""
        guard await dependencies.dictation.requestAuthorization() else {
            fail(Strings.voicePermissionDenied)
            return
        }
        startLoop()
    }

    func endAction() async {
        await halt()
        delegate?.voicePresenterDidFinish(self)
    }

    func muteAction() async {
        if viewModel.state == .muted {
            startLoop()
        } else {
            await halt()
            viewModel.state = .muted
            viewModel.caption = ""
        }
    }

    /// Cuts a reply short and goes back to listening.
    func interruptAction() async {
        guard viewModel.state == .thinking || viewModel.state == .speaking else {
            return
        }
        await halt()
        startLoop()
    }
}

private extension VoicePresenter {
    func startLoop() {
        loopTask = Task { await self.loop() }
    }

    func halt() async {
        loopTask?.cancel()
        speakTask?.cancel()
        await dependencies.dictation.stop()
        await dependencies.speech.stop()
        await dependencies.stopTurn()
        await loopTask?.value
        loopTask = nil
    }

    func fail(_ message: String) {
        viewModel.state = .unavailable
        viewModel.caption = message
    }

    func loop() async {
        while !Task.isCancelled {
            viewModel.state = .listening
            viewModel.caption = ""
            do {
                guard let words = try await listen() else {
                    // Nothing was said before the recognizer gave up; start listening afresh.
                    try? await Task.sleep(for: .milliseconds(300))
                    continue
                }
                guard !Task.isCancelled else {
                    return
                }
                await respond(to: words)
            } catch {
                logger.error("Listening failed: \(error.localizedDescription, privacy: .public)")
                fail(Strings.errorDictationUnavailable)
                return
            }
        }
    }

    /// Returns what was said once the speaker has paused, or `nil` if nothing was.
    func listen() async throws -> String? {
        let dictation = dependencies.dictation
        let updates = try await dictation.start()
        var heard = ""
        var pause: Task<Void, Never>?
        for await update in updates {
            heard = update.text
            viewModel.caption = heard
            pause?.cancel()
            if update.isFinal {
                break
            }
            pause = Task {
                try? await Task.sleep(for: Self.pauseBeforeSending)
                if !Task.isCancelled {
                    await dictation.stop()
                }
            }
        }
        pause?.cancel()
        await dictation.stop()
        let words = heard.trimmingCharacters(in: .whitespacesAndNewlines)
        return words.isEmpty ? nil : words
    }

    func respond(to words: String) async {
        viewModel.state = .thinking
        let (sentences, continuation) = AsyncStream.makeStream(of: String.self)
        let feed = SpokenReplyFeed(continuation: continuation)
        let speech = dependencies.speech
        let settings = dependencies.settings()
        let speaking = Task {
            do {
                try await speech.speak(sentences: sentences, settings: settings)
            } catch is CancellationError {
                // Interrupted by the user.
            } catch {
                self.logger.error("Speaking failed: \(error.localizedDescription, privacy: .public)")
                self.viewModel.caption = ErrorViewConfiguration(from: error).message
            }
        }
        speakTask = speaking
        await dependencies.runTurn(words) { [viewModel] delta in
            if feed.append(delta) {
                viewModel.state = .speaking
            }
            viewModel.caption = feed.caption
        }
        feed.finish()
        if !feed.caption.isEmpty, !Task.isCancelled {
            viewModel.state = .speaking
        }
        await speaking.value
    }
}
