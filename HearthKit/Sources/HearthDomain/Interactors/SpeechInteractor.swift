import Foundation

public enum SpeechError: Error, Sendable, Equatable {
    case serverNotConfigured
}

/// Speaks sentences aloud in order, synthesizing ahead while the previous one plays.
public final class SpeechInteractor: Sendable {
    private let speech: SpeechDataProvider
    private let playback: AudioPlaybackProvider

    public init(speech: SpeechDataProvider, playback: AudioPlaybackProvider) {
        self.speech = speech
        self.playback = playback
    }

    /// Returns when every sentence has been spoken; cancelling the task silences it.
    public func speak(sentences: AsyncStream<String>, settings: ServerSettings) async throws {
        guard let baseURL = settings.speechURL else {
            throw SpeechError.serverNotConfigured
        }
        let synthesize = speech.synthesize
        let voice = settings.voice
        let (clips, continuation) = AsyncThrowingStream.makeStream(of: Data.self)
        let producer = Task {
            do {
                for await sentence in sentences {
                    continuation.yield(try await synthesize(baseURL, sentence, voice))
                }
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
        defer { producer.cancel() }
        try await withTaskCancellationHandler {
            for try await clip in clips {
                try Task.checkCancellation()
                try await playback.play(clip)
            }
        } onCancel: {
            producer.cancel()
        }
    }

    /// Speaks a finished piece of text, such as a reply already on screen.
    public func speak(text: String, settings: ServerSettings) async throws {
        var chunker = SentenceChunker()
        let sentences = chunker.append(SentenceChunker.speakable(text)) + chunker.finish()
        try await speak(sentences: AsyncStream { continuation in
            sentences.forEach { continuation.yield($0) }
            continuation.finish()
        }, settings: settings)
    }

    public func stop() async {
        await playback.stop()
    }

    public func voices(settings: ServerSettings) async throws -> [String] {
        guard let baseURL = settings.speechURL else {
            throw SpeechError.serverNotConfigured
        }
        return try await speech.fetchVoices(baseURL).sorted()
    }
}
