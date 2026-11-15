// The simulator has no camera. This stand-in lets the camera's flow be walked through there; it is compiled into
// debug builds for the simulator only, and never into a build that ships.
#if DEBUG && targetEnvironment(simulator)
import CoreGraphics
import CoreText
import Foundation
import ImageIO
import QuartzCore

/// A camera that sees a drawn test card: a few plain shapes and a line of text, different for each side.
public final class SimulatedCameraService: @unchecked Sendable {
    private static let size = CGSize(width: 1600, height: 1200)

    private let lock = NSLock()
    private var isRunning = false
    private var isFacingFront = false
    private let preview: CALayer

    @MainActor
    public init() {
        preview = CALayer()
        preview.contentsGravity = .resizeAspectFill
        preview.masksToBounds = true
    }

    @MainActor
    public func previewLayer() -> CALayer {
        preview
    }

    public func start(facingFront: Bool) async {
        lock.withLock {
            isRunning = true
            isFacingFront = facingFront
        }
        await show(Self.card(facingFront: facingFront))
    }

    public func flip() async throws -> Bool {
        let facingFront = try lock.withLock {
            guard isRunning else {
                throw CameraError.notRunning
            }
            isFacingFront.toggle()
            return isFacingFront
        }
        await show(Self.card(facingFront: facingFront))
        return facingFront
    }

    public func stop() async {
        lock.withLock { isRunning = false }
        await show(nil)
    }

    public func captureFrame() async throws -> Data {
        let facingFront = try lock.withLock {
            guard isRunning else {
                throw CameraError.notRunning
            }
            return isFacingFront
        }
        guard let card = Self.card(facingFront: facingFront), let jpeg = Self.jpeg(from: card) else {
            throw CameraError.noFrame
        }
        return jpeg
    }

    @MainActor
    private func show(_ card: CGImage?) {
        preview.contents = card
    }
}

private extension SimulatedCameraService {
    /// The test card for one side: shapes a model can name, and words it can read.
    static func card(facingFront: Bool) -> CGImage? {
        let (width, height) = (Int(size.width), Int(size.height))
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        let background = facingFront ? CGColor(red: 0.20, green: 0.24, blue: 0.42, alpha: 1) : CGColor(red: 0.12, green: 0.36, blue: 0.31, alpha: 1)
        context.setFillColor(background)
        context.fill(CGRect(origin: .zero, size: size))
        context.setFillColor(CGColor(red: 0.86, green: 0.20, blue: 0.18, alpha: 1))
        context.fillEllipse(in: CGRect(x: 180, y: 520, width: 380, height: 380))
        context.setFillColor(CGColor(red: 0.16, green: 0.42, blue: 0.86, alpha: 1))
        context.fill(CGRect(x: 640, y: 520, width: 360, height: 360))
        context.setFillColor(CGColor(red: 0.96, green: 0.80, blue: 0.20, alpha: 1))
        context.move(to: CGPoint(x: 1080, y: 520))
        context.addLine(to: CGPoint(x: 1460, y: 520))
        context.addLine(to: CGPoint(x: 1270, y: 900))
        context.closePath()
        context.fillPath()
        draw(facingFront ? "FRONT CAMERA 7" : "HEARTH TEST 42", in: context)
        return context.makeImage()
    }

    static func draw(_ words: String, in context: CGContext) {
        let font = CTFontCreateWithName("Helvetica-Bold" as CFString, 150, nil)
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(red: 1, green: 1, blue: 1, alpha: 1)
        ]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: words, attributes: attributes))
        let width = CTLineGetBoundsWithOptions(line, []).width
        context.textPosition = CGPoint(x: (size.width - width) / 2, y: 230)
        CTLineDraw(line, context)
    }

    static func jpeg(from image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, "public.jpeg" as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }
}
#endif
