import AVFoundation
import Speech

/// What the recogniser has heard so far, and whether that is its last word.
public struct DictationUpdateDTO: Sendable, Equatable {
    public let text: String
    public let isFinal: Bool
}

/// Why listening could not begin.
public enum DictationError: Error, Sendable {
    /// The phone has no speech recogniser for its language, or it cannot be used just now.
    case recognizerUnavailable
    /// The microphone offers no audio to listen to.
    case microphoneUnavailable
}

/// Live speech-to-text from the microphone, using the phone's own recogniser.
@MainActor
public final class DictationService {
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var continuation: AsyncStream<DictationUpdateDTO>.Continuation?
    private var routeObserver: (any NSObjectProtocol)?

    public init() {}

    /// Asks for leave to recognise speech and then to use the microphone; true only if both are given.
    public func requestAuthorization() async -> Bool {
        guard await Self.requestSpeechAuthorization() else {
            return false
        }
        return await AVAudioApplication.requestRecordPermission()
    }

    /// Starts listening. The stream ends when recognition finishes or `stop()` is called.
    public func start() throws -> AsyncStream<DictationUpdateDTO> {
        stop()
        guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else {
            throw DictationError.recognizerUnavailable
        }
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        // Keep speech on the phone wherever the recogniser can manage without Apple's servers.
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        guard Self.installTap(on: engine.inputNode, feeding: request) else {
            throw DictationError.microphoneUnavailable
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            engine.inputNode.removeTap(onBus: 0)
            throw error
        }

        let (stream, continuation) = AsyncStream.makeStream(of: DictationUpdateDTO.self)
        self.request = request
        self.continuation = continuation
        self.task = Self.recognize(with: recognizer, request: request, continuation: continuation)
        observeRouteChanges()
        return stream
    }

    /// Stops listening and ends the stream. Harmless when nothing is running.
    public func stop() {
        if let routeObserver {
            NotificationCenter.default.removeObserver(routeObserver)
        }
        routeObserver = nil
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        continuation?.finish()
        request = nil
        task = nil
        continuation = nil
    }

    /// Watches for the microphone changing under the engine, as when headphones are put in or taken out.
    private func observeRouteChanges() {
        routeObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.resumeAfterRouteChange() }
        }
    }

    /// The engine stops itself when the microphone changes. Listening carries on with the new one, feeding the same
    /// recognition, so what was already said is kept. If the new microphone cannot be used, listening ends.
    private func resumeAfterRouteChange() {
        guard let request else {
            return
        }
        engine.stop()
        guard Self.installTap(on: engine.inputNode, feeding: request) else {
            stop()
            return
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            stop()
        }
    }
}

// The callbacks below arrive on audio and recogniser queues, so they are built outside the main actor.
private extension DictationService {
    nonisolated static func requestSpeechAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    /// Feeds the microphone's audio to the recogniser. False when the microphone has no usable format.
    nonisolated static func installTap(on node: AVAudioInputNode, feeding request: SFSpeechAudioBufferRecognitionRequest) -> Bool {
        let format = node.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            return false
        }
        node.removeTap(onBus: 0)
        node.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
        return true
    }

    /// Passes on each transcription as it firms up, and ends the stream on the last one or on a failure.
    nonisolated static func recognize(
        with recognizer: SFSpeechRecognizer,
        request: SFSpeechAudioBufferRecognitionRequest,
        continuation: AsyncStream<DictationUpdateDTO>.Continuation
    ) -> SFSpeechRecognitionTask {
        recognizer.recognitionTask(with: request) { result, error in
            if let result {
                continuation.yield(DictationUpdateDTO(text: result.bestTranscription.formattedString, isFinal: result.isFinal))
            }
            if error != nil || result?.isFinal == true {
                continuation.finish()
            }
        }
    }
}
