import Foundation

/// A row of dots drawn to the loudness of a voice: the middle one swells the most and those beside it less,
/// so that the row bulges as someone speaks and lies flat when they stop.
struct VoiceLevelDots: Hashable {
    /// One dot, and how large it is drawn against its resting size.
    struct Dot: Identifiable, Hashable {
        let id: Int
        let scale: Double
    }

    /// How large the middle dot is drawn at the top of the voice.
    static let fullScale = 2.0
    /// How much of the voice reaches the dots at either end.
    static let edgeReach = 0.4

    let dots: [Dot]

    /// - Parameters:
    ///   - level: How loud the voice is, from 0 to 1. Anything outside is brought within; nonsense is silence.
    ///   - count: How many dots are in the row.
    init(level: Double, count: Int = 5) {
        let level = level.isFinite ? min(max(level, 0), 1) : 0
        let middle = Double(count - 1) / 2
        dots = (0..<max(count, 0)).map { index in
            let distance = middle > 0 ? abs(Double(index) - middle) / middle : 0
            let reach = 1 - (1 - Self.edgeReach) * distance
            return Dot(id: index, scale: 1 + (Self.fullScale - 1) * level * reach)
        }
    }
}
