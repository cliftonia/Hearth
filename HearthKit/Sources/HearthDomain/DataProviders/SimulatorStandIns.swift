// The simulator has no camera, and nobody to speak to it. These stand-ins let a voice conversation with the camera
// be walked through there; they are compiled into debug builds for the simulator only, and never into a build that ships.
#if DEBUG && targetEnvironment(simulator)
import Foundation
import HearthData
import os

public extension CameraProvider {
    /// A camera that sees a drawn test card, different for each side, and is always allowed.
    @MainActor
    static func simulated() -> CameraProvider {
        let service = SimulatedCameraService()
        return CameraProvider(
            requestAuthorization: { true },
            start: { position in await service.start(facingFront: position == .front) },
            stop: { await service.stop() },
            flip: { try await service.flip() ? .front : .back },
            captureFrame: { try await service.captureFrame() },
            previewLayer: { service.previewLayer() }
        )
    }
}

public extension DictationProvider {
    /// A listener that hears the given words once, a while after listening begins, and nothing after that.
    /// With no words it hears nothing at all, so that noise near the Mac's microphone is never sent as a turn.
    ///
    /// - Parameter delay: How long listening lasts before the words are heard, which leaves time to turn the camera on.
    static func scripted(words: String, after delay: Duration = .seconds(20)) -> DictationProvider {
        let state = OSAllocatedUnfairLock(initialState: ScriptedDictation(hasWordsLeft: !words.isEmpty))
        return DictationProvider(
            requestAuthorization: { true },
            start: {
                let (stream, continuation) = AsyncStream.makeStream(of: DictationUpdate.self)
                let speaking = Task {
                    try? await Task.sleep(for: delay)
                    let speaks = state.withLock { state in
                        guard !Task.isCancelled, state.hasWordsLeft else {
                            return false
                        }
                        state.hasWordsLeft = false
                        return true
                    }
                    if speaks {
                        continuation.yield(DictationUpdate(text: words, isFinal: true))
                        continuation.finish()
                    }
                }
                let previous = state.withLock { state in
                    let previous = state.listening
                    state.listening = ScriptedDictation.Listening(speaking: speaking, continuation: continuation)
                    return previous
                }
                previous?.end()
                return stream
            },
            stop: {
                state.withLock { state in
                    let listening = state.listening
                    state.listening = nil
                    return listening
                }?.end()
            }
        )
    }
}

public extension SpeechDataProvider {
    /// A voice that says nothing and asks no server, for a conversation whose replies are only read on screen.
    static var silent: SpeechDataProvider {
        SpeechDataProvider(synthesize: { _, _, _ in Data() }, fetchVoices: { _ in [] })
    }
}

public extension AudioPlaybackProvider {
    /// A player that plays nothing.
    static var silent: AudioPlaybackProvider {
        AudioPlaybackProvider(play: { _ in }, stop: {})
    }
}

/// What a scripted listener keeps between calls.
private struct ScriptedDictation: Sendable {
    /// One spell of listening: the wait before the words, and where they go.
    struct Listening: Sendable {
        let speaking: Task<Void, Never>
        let continuation: AsyncStream<DictationUpdate>.Continuation

        func end() {
            speaking.cancel()
            continuation.finish()
        }
    }

    var hasWordsLeft: Bool
    var listening: Listening?
}
#endif
