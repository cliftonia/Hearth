import Foundation
import HearthData
import QuartzCore

/// How the domain works the camera: shows what it sees, and takes one still picture at a time. Nothing is recorded.
public struct CameraProvider: Sendable {
    /// Whether the camera may be used. The system asks the user the first time only.
    public let requestAuthorization: @Sendable () async -> Bool
    /// Turns the camera on, facing the given way where there is a choice.
    public let start: @Sendable (CameraPositionKind) async throws -> Void
    /// Turns the camera off and lets go of it. Harmless when it is off.
    public let stop: @Sendable () async -> Void
    /// Changes to the camera on the other side, and returns which way it now faces.
    public let flip: @Sendable () async throws -> CameraPositionKind
    /// One still picture of what the camera sees now, as JPEG data at the camera's own size.
    public let captureFrame: @Sendable () async throws -> Data
    /// What cameras the device has.
    public let availability: @Sendable () -> CameraAvailability
    /// The layer the live picture is drawn in, for a view to hold. It is the same layer every time.
    public let previewLayer: @MainActor @Sendable () -> CALayer

    /// - Parameters:
    ///   - availability: Left out, the device is taken to have a camera on each side.
    ///   - previewLayer: Left out, the live picture is not shown.
    public init(
        requestAuthorization: @escaping @Sendable () async -> Bool,
        start: @escaping @Sendable (CameraPositionKind) async throws -> Void,
        stop: @escaping @Sendable () async -> Void,
        flip: @escaping @Sendable () async throws -> CameraPositionKind,
        captureFrame: @escaping @Sendable () async throws -> Data,
        availability: @escaping @Sendable () -> CameraAvailability = { CameraAvailability(hasCamera: true, canFlip: true) },
        previewLayer: @escaping @MainActor @Sendable () -> CALayer = { CALayer() }
    ) {
        self.requestAuthorization = requestAuthorization
        self.start = start
        self.stop = stop
        self.flip = flip
        self.captureFrame = captureFrame
        self.availability = availability
        self.previewLayer = previewLayer
    }
}

public extension CameraProvider {
    /// Backed by the device's own cameras.
    @MainActor
    static func live() -> CameraProvider {
        let service = CameraService()
        return CameraProvider(
            requestAuthorization: { await service.requestAuthorization() },
            start: { position in try await service.start(facingFront: position == .front) },
            stop: { await service.stop() },
            flip: { try await service.flip() ? .front : .back },
            captureFrame: { try await service.captureFrame() },
            availability: { CameraAvailability(hasCamera: service.hasCamera(), canFlip: service.canFlip()) },
            previewLayer: { service.previewLayer() }
        )
    }
}
