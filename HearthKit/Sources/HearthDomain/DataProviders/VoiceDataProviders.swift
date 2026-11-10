import Foundation
import HearthData

public struct SpeechDataProvider: Sendable {
    /// Server, text and voice in; audio out.
    public let synthesize: @Sendable (URL, String, String) async throws -> Data
    public let fetchVoices: @Sendable (URL) async throws -> [String]

    public init(
        synthesize: @escaping @Sendable (URL, String, String) async throws -> Data,
        fetchVoices: @escaping @Sendable (URL) async throws -> [String]
    ) {
        self.synthesize = synthesize
        self.fetchVoices = fetchVoices
    }
}

public struct AudioPlaybackProvider: Sendable {
    /// Returns once the clip has finished playing or been stopped.
    public let play: @Sendable (Data) async throws -> Void
    public let stop: @Sendable () async -> Void

    public init(play: @escaping @Sendable (Data) async throws -> Void, stop: @escaping @Sendable () async -> Void) {
        self.play = play
        self.stop = stop
    }
}

public struct DictationUpdate: Sendable, Equatable {
    public let text: String
    public let isFinal: Bool

    public init(text: String, isFinal: Bool) {
        self.text = text
        self.isFinal = isFinal
    }
}

public struct DictationProvider: Sendable {
    public let requestAuthorization: @Sendable () async -> Bool
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
