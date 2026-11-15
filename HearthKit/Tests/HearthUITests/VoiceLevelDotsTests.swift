import Foundation
@testable import HearthUI
import Testing

/// How the loudness of a voice is spread over the row of dots in the held composer.
struct VoiceLevelDotsTests {
    @Test func `in silence every dot keeps its resting size`() {
        let subject = VoiceLevelDots(level: 0)

        #expect(subject.dots.map(\.id) == [0, 1, 2, 3, 4])
        #expect(subject.dots.allSatisfy { $0.scale == 1 })
    }

    @Test func `at the top of the voice the middle dot is largest and the row falls away evenly on both sides`() {
        let scales = VoiceLevelDots(level: 1).dots.map(\.scale)

        #expect(scales[2] == VoiceLevelDots.fullScale)
        #expect(scales[0] == scales[4])
        #expect(scales[1] == scales[3])
        #expect(scales[0] < scales[1])
        #expect(scales[1] < scales[2])
        #expect(abs(scales[0] - (1 + (VoiceLevelDots.fullScale - 1) * VoiceLevelDots.edgeReach)) < 0.000_1)
    }

    @Test func `a louder voice makes every dot larger`() {
        let quiet = VoiceLevelDots(level: 0.2).dots.map(\.scale)
        let loud = VoiceLevelDots(level: 0.8).dots.map(\.scale)

        #expect(zip(quiet, loud).allSatisfy { $0 < $1 })
    }

    @Test(arguments: [(-3.0, 0.0), (7.0, 1.0), (Double.nan, 0.0), (Double.infinity, 0.0)])
    func `a level outside zero to one is brought within, and nonsense is silence`(level: Double, clamped: Double) {
        #expect(VoiceLevelDots(level: level) == VoiceLevelDots(level: clamped))
    }

    @Test(arguments: [0, 1, 4])
    func `the row has as many dots as it is asked for`(count: Int) {
        let subject = VoiceLevelDots(level: 1, count: count)

        #expect(subject.dots.count == count)
        #expect(subject.dots.allSatisfy { $0.scale >= 1 && $0.scale <= VoiceLevelDots.fullScale })
    }
}
