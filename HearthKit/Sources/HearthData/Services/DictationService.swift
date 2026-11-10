import AVFoundation
import Speech

public struct DictationUpdateDTO: Sendable, Equatable {
    public let text: String
    public let isFinal: Bool
}

public enum DictationError: Error, Sendable {
    case recognizerUnavailable
    case microphoneUnavailable
}

/// Live speech-to-text from the microphone, using the phone's own recognizer.
@MainActor
public final class DictationService {
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var continuation: AsyncStream<DictationUpdateDTO>.Continuation?

    public init() {}

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
        // Keep speech on the phone wherever the recognizer can manage without Apple's servers.
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        guard Self.installTap(on: engine.inputNode, feeding: request) else {
            throw DictationError.microphoneUnavailable
        }
        engine.prepare()
        try engine.start()

        let (stream, continuation) = AsyncStream.makeStream(of: DictationUpdateDTO.self)
        self.request = request
        self.continuation = continuation
        self.task = Self.recognize(with: recognizer, request: request, continuation: continuation)
        return stream
    }

    public func stop() {
        if engine.isRunning {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }
        request?.endAudio()
        task?.cancel()
        continuation?.finish()
        request = nil
        task = nil
        continuation = nil
    }
}

// The callbacks below arrive on audio and recognizer queues, so they are built outside the main actor.
private extension DictationService {
    nonisolated static func requestSpeechAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

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
