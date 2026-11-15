import CoreGraphics
@testable import HearthUI
import Testing

/// How much of the voice screen the camera's picture takes, on a phone and on an iPad.
struct VoiceCameraLayoutTests {
    @Test func `on a phone the card takes the width there is`() {
        let size = VoiceCameraLayout.cardSize(in: CGSize(width: 393, height: 620), margin: 28)

        #expect(size == CGSize(width: 337, height: 252))
    }

    @Test func `on an iPad the card stops at its widest`() {
        let size = VoiceCameraLayout.cardSize(in: CGSize(width: 744, height: 950), margin: 28)

        #expect(size == CGSize(width: 520, height: 390))
    }

    @Test func `where there is little height the card gives way and keeps its shape`() {
        let size = VoiceCameraLayout.cardSize(in: CGSize(width: 1133, height: 560), margin: 28)

        #expect(size.height == (560 * VoiceCameraLayout.heightShare).rounded(.down))
        #expect(abs(size.width / size.height - VoiceCameraLayout.aspectRatio) < 0.01)
    }

    @Test func `no space at all gives a card of no size, never a negative one`() {
        #expect(VoiceCameraLayout.cardSize(in: .zero, margin: 28) == .zero)
    }
}
