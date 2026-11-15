import Foundation

/// Turns a slice of microphone audio into how loud it is, from 0 for silence to 1 for a raised voice.
///
/// The loudness is measured in decibels, as the ear hears it, so that quiet speech still registers and a shout
/// does not swamp everything else.
public enum VoiceLevelMeter {
    /// The quietest sound that registers at all, in decibels below full scale. Room noise sits beneath it.
    static let floorDecibels = -50.0
    /// The loudness that counts as full, in decibels below full scale. Speech close to the microphone reaches it.
    static let ceilingDecibels = -10.0

    /// The level of the samples, each of which runs from -1 to 1. Nothing to measure is silence.
    public static func level(of samples: UnsafeBufferPointer<Float>) -> Double {
        guard !samples.isEmpty else {
            return 0
        }
        let meanSquare = samples.reduce(0.0) { $0 + Double($1) * Double($1) } / Double(samples.count)
        guard meanSquare.isFinite, meanSquare > 0 else {
            return 0
        }
        let decibels = 10 * log10(meanSquare)
        return min(max((decibels - floorDecibels) / (ceilingDecibels - floorDecibels), 0), 1)
    }
}
