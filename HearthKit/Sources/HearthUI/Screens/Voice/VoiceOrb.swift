import SwiftUI

/// The glowing orb at the heart of a voice conversation; it breathes faster the busier things are.
struct VoiceOrb: View {
    /// The diameters of the orb and the two halos around it.
    private static let coreDiameter: CGFloat = 150
    private static let innerHaloDiameter: CGFloat = 190
    private static let outerHaloDiameter: CGFloat = 230

    let state: VoiceStateKind

    @State private var isExpanded = false

    var body: some View {
        ZStack {
            Circle()
                .fill(HearthColor.pine.opacity(0.06))
                .frame(width: Self.outerHaloDiameter, height: Self.outerHaloDiameter)
                .scaleEffect(isExpanded ? 1.08 : 0.92)
            Circle()
                .fill(HearthColor.pine.opacity(0.10))
                .frame(width: Self.innerHaloDiameter, height: Self.innerHaloDiameter)
                .scaleEffect(isExpanded ? 1.06 : 0.95)
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
                .scaleEffect(isExpanded ? 1.04 : 0.97)
        }
        .saturation(state == .muted || state == .unavailable ? 0.15 : 1)
        .opacity(state == .muted || state == .unavailable ? 0.6 : 1)
        .animation(.easeInOut(duration: breathDuration).repeatForever(autoreverses: true), value: isExpanded)
        .animation(.easeInOut(duration: 0.3), value: state)
        .onAppear { isExpanded = true }
        .onChange(of: state) {
            // Restart the breathing so the new pace takes hold.
            isExpanded.toggle()
        }
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
