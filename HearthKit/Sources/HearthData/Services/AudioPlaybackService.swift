import AVFoundation

/// Plays one clip of audio at a time and returns when it has finished or been stopped.
@MainActor
public final class AudioPlaybackService {
    private var player: AVAudioPlayer?
    private var delegate: PlaybackDelegate?

    public init() {}

    public func play(_ data: Data) async throws {
        stop()
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .spokenAudio)
        try session.setActive(true)

        let player = try AVAudioPlayer(data: data)
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                let delegate = PlaybackDelegate { continuation.resume() }
                player.delegate = delegate
                self.player = player
                self.delegate = delegate
                if !player.play() {
                    delegate.finish()
                }
            }
        } onCancel: {
            Task { @MainActor in self.stop() }
        }
    }

    public func stop() {
        player?.stop()
        delegate?.finish()
        player = nil
        delegate = nil
    }
}

private final class PlaybackDelegate: NSObject, @unchecked Sendable {
    private let lock = NSLock()
    private var onFinish: (@Sendable () -> Void)?

    init(onFinish: @escaping @Sendable () -> Void) {
        self.onFinish = onFinish
    }

    /// Calls the completion once, however many times playback reports an ending.
    func finish() {
        lock.lock()
        let completion = onFinish
        onFinish = nil
        lock.unlock()
        completion?()
    }
}

extension PlaybackDelegate: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        finish()
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: (any Error)?) {
        finish()
    }
}
