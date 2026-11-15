import Foundation
@testable import HearthData
import Testing

/// How loud a slice of microphone audio is taken to be.
struct VoiceLevelMeterTests {
    /// The level of a steady tone that swings between plus and minus the given height.
    private func level(ofToneWithHeight height: Float) -> Double {
        let samples = (0..<1024).map { $0.isMultiple(of: 2) ? height : -height }
        return samples.withUnsafeBufferPointer(VoiceLevelMeter.level(of:))
    }

    @Test func `no audio and silent audio are both silence`() {
        #expect([Float]().withUnsafeBufferPointer(VoiceLevelMeter.level(of:)) == 0)
        #expect(level(ofToneWithHeight: 0) == 0)
    }

    @Test func `room noise below the floor does not register and a full signal is the top`() {
        #expect(level(ofToneWithHeight: 0.001) == 0)
        #expect(level(ofToneWithHeight: 1) == 1)
    }

    @Test func `a louder voice gives a higher level, always between zero and one`() {
        let levels = [Float(0.005), 0.02, 0.08, 0.25].map(level(ofToneWithHeight:))

        #expect(levels == levels.sorted())
        #expect(Set(levels).count == levels.count)
        #expect(levels.allSatisfy { $0 > 0 && $0 < 1 })
    }

    @Test func `the level follows decibels, so ten times the signal is half the scale`() {
        // Twenty decibels apart, on a scale that runs over forty.
        let difference = level(ofToneWithHeight: 0.1) - level(ofToneWithHeight: 0.01)

        #expect(abs(difference - 0.5) < 0.000_1)
    }
}
