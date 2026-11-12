import Foundation
import HearthData

/// How the domain turns text into audio.
public struct SpeechDataProvider: Sendable {
    /// Server, text and voice in; audio out.
    public let synthesize: @Sendable (URL, String, String) async throws -> Data
    /// The voices the given server can speak in.
    public let fetchVoices: @Sendable (URL) async throws -> [String]

    public init(
        synthesize: @escaping @Sendable (URL, String, String) async throws -> Data,
        fetchVoices: @escaping @Sendable (URL) async throws -> [String]
    ) {
        self.synthesize = synthesize
        self.fetchVoices = fetchVoices
    }
}

/// How the domain plays a clip of audio.
public struct AudioPlaybackProvider: Sendable {
    /// Returns once the clip has finished playing or been stopped.
    public let play: @Sendable (Data) async throws -> Void
    public let stop: @Sendable () async -> Void

    public init(play: @escaping @Sendable (Data) async throws -> Void, stop: @escaping @Sendable () async -> Void) {
        self.play = play
        self.stop = stop
    }
}

/// What has been heard so far, and whether that is the recogniser's last word.
public struct DictationUpdate: Sendable, Equatable {
    public let text: String
    public let isFinal: Bool

    public init(text: String, isFinal: Bool) {
        self.text = text
        self.isFinal = isFinal
    }
}

/// How the domain listens to the user speak.
public struct DictationProvider: Sendable {
    /// Whether the user allows both speech recognition and the microphone.
    public let requestAuthorization: @Sendable () async -> Bool
    /// Starts listening. The stream ends when recognition finishes or `stop` is called.
    public let start: @Sendable () async throws -> AsyncStream<DictationUpdate>
    public let stop: @Sendable () async -> Void

    public init(
        requestAuthorization: @escaping @Sendable () async -> Bool,
        start: @escaping @Sendable () async throws -> AsyncStream<DictationUpdate>,
        stop: @escaping @Sendable () async -> Void
    ) {
        self.requestAuthorization = requestAuthorization
        self.start = start
        self.stop = stop
    }
}

public extension SpeechDataProvider {
    /// Backed by an OpenAI-compatible speech server.
    static func live(service: SpeechService = SpeechService()) -> SpeechDataProvider {
        SpeechDataProvider(
            synthesize: { baseURL, text, voice in
                try await service.synthesize(baseURL: baseURL, text: text, voice: voice)
            },
            fetchVoices: { baseURL in
                try await service.fetchVoices(baseURL: baseURL)
            }
        )
    }
}

public extension AudioPlaybackProvider {
    /// Backed by the phone's audio player; every clip goes through the same one.
    @MainActor
    static func live() -> AudioPlaybackProvider {
        let service = AudioPlaybackService()
        return AudioPlaybackProvider(
            play: { data in try await service.play(data) },
            stop: { await service.stop() }
        )
    }
}

public extension DictationProvider {
    /// Backed by the phone's own speech recogniser.
    @MainActor
    static func live() -> DictationProvider {
        let service = DictationService()
        return DictationProvider(
            requestAuthorization: { await service.requestAuthorization() },
            start: {
                let updates = try await service.start()
                return AsyncStream { continuation in
                    let task = Task {
                        for await update in updates {
                            continuation.yield(DictationUpdate(text: update.text, isFinal: update.isFinal))
                        }
                        continuation.finish()
                    }
                    continuation.onTermination = { _ in task.cancel() }
                }
            },
            stop: { await service.stop() }
        )
    }
}
