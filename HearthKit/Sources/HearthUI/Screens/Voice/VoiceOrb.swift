import SwiftUI

/// The glowing orb at the heart of a voice conversation; it breathes faster the busier things are. With Reduce Motion
/// on it holds still, and only its colour says when it is muted.
struct VoiceOrb: View {
    /// The diameters of the orb and the two halos around it.
    private static let coreDiameter: CGFloat = 150
    private static let innerHaloDiameter: CGFloat = 190
    /// The outer halo is the whole of the orb, so the voice screen reads it to make room.
    static let outerHaloDiameter: CGFloat = 230

    let state: VoiceStateKind

    @State private var isExpanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle()
                .fill(HearthColor.pine.opacity(0.06))
                .frame(width: Self.outerHaloDiameter, height: Self.outerHaloDiameter)
                .scaleEffect(breath(1.08, 0.92))
            Circle()
                .fill(HearthColor.pine.opacity(0.10))
                .frame(width: Self.innerHaloDiameter, height: Self.innerHaloDiameter)
                .scaleEffect(breath(1.06, 0.95))
            Circle()
                .fill(
                    RadialGradient(
                        colors: HearthColor.orb,
                        center: UnitPoint(x: 0.35, y: 0.3),
                        startRadius: 4,
                        endRadius: 130
                    )
                )
                .frame(width: Self.coreDiameter, height: Self.coreDiameter)
                .scaleEffect(breath(1.04, 0.97))
        }
        .saturation(state == .muted || state == .unavailable ? 0.15 : 1)
        .opacity(state == .muted || state == .unavailable ? 0.6 : 1)
        .animation(reduceMotion ? nil : .easeInOut(duration: breathDuration).repeatForever(autoreverses: true), value: isExpanded)
        .animation(.easeInOut(duration: 0.3), value: state)
        .onAppear { isExpanded = true }
        .onChange(of: state) {
            // Restart the breathing so the new pace takes hold.
            isExpanded.toggle()
        }
    }

    /// A layer's scale at the top or bottom of a breath, or at rest when motion is reduced.
    private func breath(_ expanded: CGFloat, _ contracted: CGFloat) -> CGFloat {
        guard !reduceMotion else {
            return 1
        }
        return isExpanded ? expanded : contracted
    }

    /// The seconds one breath in or out takes.
    private var breathDuration: Double {
        switch state {
        case .listening:
            1.6
        case .thinking:
            0.5
        case .speaking:
            0.9
        case .muted, .unavailable:
            3
        }
    }
}
