import AVFoundation
import CoreImage
import QuartzCore

/// Why the camera gave nothing.
public enum CameraError: Error, Sendable, Equatable {
    /// The device has no camera that can be used just now.
    case unavailable
    /// A picture was asked for while the camera was off.
    case notRunning
    /// The camera was on but handed over no picture in time.
    case noFrame
}

/// The camera, shown live and asked for one still picture at a time.
///
/// Nothing is recorded. The camera's pictures pass by unseen, and one is kept only when `captureFrame()` asks for
/// it. Everything that touches the capture session happens on one queue, which is what makes the class safe to share.
public final class CameraService: @unchecked Sendable {
    /// How long a picture is waited for before the turn goes without one.
    private static let frameWait: DispatchTimeInterval = .milliseconds(1500)

    private let queue = DispatchQueue(label: "hearth.camera")
    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let grabber = CameraFrameGrabber()
    private let preview: AVCaptureVideoPreviewLayer
    /// Whether the camera now in use faces the user. Touched on the queue only.
    private var isFacingFront = false
    /// Keeps the picture upright as the device turns. Touched on the queue only.
    private var rotation: AVCaptureDevice.RotationCoordinator?
    private var rotationObservations: [NSKeyValueObservation] = []

    @MainActor
    public init() {
        preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
    }

    /// The layer the live picture is drawn in. It shows nothing while the camera is off.
    @MainActor
    public func previewLayer() -> CALayer {
        preview
    }

    /// Whether the device has a camera at all.
    public func hasCamera() -> Bool {
        !Self.devices().isEmpty
    }

    /// Whether there is both a camera facing the user and one facing away.
    public func canFlip() -> Bool {
        let positions = Set(Self.devices().map(\.position))
        return positions.contains(.front) && positions.contains(.back)
    }

    /// Whether the camera may be used. The system asks the user the first time only.
    public func requestAuthorization() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            true
        case .notDetermined:
            await AVCaptureDevice.requestAccess(for: .video)
        case .denied, .restricted:
            false
        @unknown default:
            false
        }
    }

    /// Turns the camera on, or changes which one is on.
    public func start(facingFront: Bool) async throws {
        try await onQueue {
            try self.configure(facingFront: facingFront)
            if !self.session.isRunning {
                self.session.startRunning()
            }
            guard self.session.isRunning else {
                self.shutDown()
                throw CameraError.unavailable
            }
        }
    }

    /// Changes to the camera on the other side, and returns whether it faces the user.
    public func flip() async throws -> Bool {
        try await onQueue {
            guard self.session.isRunning else {
                throw CameraError.notRunning
            }
            try self.configure(facingFront: !self.isFacingFront)
            return self.isFacingFront
        }
    }

    /// Turns the camera off and lets go of it, so that the system's indicator goes out. Harmless when it is off.
    public func stop() async {
        await withCheckedContinuation { continuation in
            queue.async {
                self.shutDown()
                continuation.resume()
            }
        }
    }

    /// One still picture of what the camera sees now, as JPEG data at the camera's own size.
    public func captureFrame() async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                guard self.session.isRunning else {
                    continuation.resume(throwing: CameraError.notRunning)
                    return
                }
                let request = self.grabber.ask(continuation)
                self.queue.asyncAfter(deadline: .now() + Self.frameWait) {
                    self.grabber.giveUp(on: request)
                }
            }
        }
    }
}

// Everything below runs on the queue.
private extension CameraService {
    /// The cameras that could be used, the one facing away first where there is a choice.
    static func devices() -> [AVCaptureDevice] {
        AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .external], mediaType: .video, position: .unspecified)
            .devices
            .sorted { $0.position == .back && $1.position != .back }
    }

    func onQueue<Value: Sendable>(_ work: @escaping @Sendable () throws -> Value) async throws -> Value {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                continuation.resume(with: Result { try work() })
            }
        }
    }

    /// Points the session at the camera on the wanted side, or at the only camera there is.
    func configure(facingFront: Bool) throws {
        let devices = Self.devices()
        let wanted: AVCaptureDevice.Position = facingFront ? .front : .back
        guard let device = devices.first(where: { $0.position == wanted }) ?? devices.first,
              let input = try? AVCaptureDeviceInput(device: device) else {
            throw CameraError.unavailable
        }
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.inputs.forEach { session.removeInput($0) }
        guard session.canAddInput(input) else {
            throw CameraError.unavailable
        }
        session.addInput(input)
        if !session.outputs.contains(output) {
            guard session.canAddOutput(output) else {
                throw CameraError.unavailable
            }
            // A picture that arrives while another is being handled is of no use; only the newest is wanted.
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(grabber, queue: queue)
            session.addOutput(output)
        }
        #if !targetEnvironment(macCatalyst)
        // On an iPad, keep the camera when another app shares the screen.
        if session.isMultitaskingCameraAccessSupported {
            session.isMultitaskingCameraAccessEnabled = true
        }
        #endif
        isFacingFront = device.position == .front
        followRotation(of: device)
    }

    /// Keeps both the live picture and the still one upright, whichever way the device is held.
    func followRotation(of device: AVCaptureDevice) {
        rotationObservations = []
        let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: preview)
        rotation = coordinator
        rotationObservations = [
            coordinator.observe(\.videoRotationAngleForHorizonLevelPreview, options: [.initial, .new]) { [weak self] coordinator, _ in
                let angle = coordinator.videoRotationAngleForHorizonLevelPreview
                guard let self else {
                    return
                }
                Task { @MainActor in self.turnPreview(to: angle) }
            },
            coordinator.observe(\.videoRotationAngleForHorizonLevelCapture, options: [.initial, .new]) { [weak self] coordinator, _ in
                let angle = coordinator.videoRotationAngleForHorizonLevelCapture
                guard let self else {
                    return
                }
                queue.async { self.turnOutput(to: angle) }
            }
        ]
    }

    @MainActor
    func turnPreview(to angle: CGFloat) {
        if let connection = preview.connection, connection.isVideoRotationAngleSupported(angle) {
            connection.videoRotationAngle = angle
        }
    }

    func turnOutput(to angle: CGFloat) {
        if let connection = output.connection(with: .video), connection.isVideoRotationAngleSupported(angle) {
            connection.videoRotationAngle = angle
        }
    }

    /// Stops the session and removes the camera from it. A picture still waited for is given up on.
    func shutDown() {
        grabber.giveUp()
        rotationObservations = []
        rotation = nil
        if session.isRunning {
            session.stopRunning()
        }
        session.beginConfiguration()
        session.inputs.forEach { session.removeInput($0) }
        session.commitConfiguration()
    }
}

/// Receives the camera's pictures, and keeps one only when one has been asked for. Used on the camera's queue only.
private final class CameraFrameGrabber: NSObject, @unchecked Sendable {
    private let context = CIContext()
    private var waiting: CheckedContinuation<Data, any Error>?
    /// Tells one request from the next, so that a wait that ran out cannot end a later request.
    private var request = 0

    /// Asks for the next picture. Returns the number of the request, for giving up on it.
    func ask(_ continuation: CheckedContinuation<Data, any Error>) -> Int {
        giveUp()
        request += 1
        waiting = continuation
        return request
    }

    /// Ends the request with no picture, if it is still the one waiting. With no number, ends whichever is waiting.
    func giveUp(on number: Int? = nil) {
        guard number == nil || number == request else {
            return
        }
        waiting?.resume(throwing: CameraError.noFrame)
        waiting = nil
    }
}

extension CameraFrameGrabber: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Nobody asked: the picture is let go without being looked at.
        guard let waiting else {
            return
        }
        self.waiting = nil
        guard let pixels = CMSampleBufferGetImageBuffer(sampleBuffer),
              let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let jpeg = context.jpegRepresentation(of: CIImage(cvPixelBuffer: pixels), colorSpace: colorSpace) else {
            waiting.resume(throwing: CameraError.noFrame)
            return
        }
        waiting.resume(returning: jpeg)
    }
}
