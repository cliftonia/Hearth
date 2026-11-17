import SwiftUI

/// What the composer shows while it is held down and listening: a stop control, what to do, how loud the voice
/// is, and the send arrow waiting its turn.
struct HoldToTalkRow: View {
    /// How dim the send arrow is while there is nothing yet to send.
    private static let waitingSendOpacity = 0.35

    /// How loud the voice is, from 0 to 1.
    let level: Double
    /// Stops the recording, for a finger that would sooner tap than let go.
    let stopAction: () -> Void

    var body: some View {
        HStack(spacing: HearthSpacing.s10) {
            Button(action: stopAction) {
                Image(systemName: "stop.fill")
                    .font(.hearth(.footnote).weight(.bold))
                    .foregroundStyle(HearthColor.onPine)
                    .frame(width: HearthSize.sendButton, height: HearthSize.sendButton)
                    .background(HearthColor.pine, in: Circle())
                    .minimumHitTarget()
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Strings.stopDictation)
            Text(Strings.releaseToStop)
                .font(.hearth(.body))
                .foregroundStyle(HearthColor.ink)
                .lineLimit(1)
            VoiceLevelDotsRow(level: level)
                .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "arrow.up")
                .font(.hearth(.footnote).weight(.bold))
                .foregroundStyle(HearthColor.onPine)
                .frame(width: HearthSize.sendButton, height: HearthSize.sendButton)
                .background(HearthColor.pine, in: Circle())
                .opacity(Self.waitingSendOpacity)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Small dots that swell with the voice. They are decoration: VoiceOver is told nothing of them.
private struct VoiceLevelDotsRow: View {
    private static let dotSide: CGFloat = 6

    let level: Double

    var body: some View {
        HStack(spacing: HearthSpacing.s8) {
            ForEach(VoiceLevelDots(level: level).dots) { dot in
                Circle()
                    .fill(HearthColor.pine)
                    .frame(width: Self.dotSide, height: Self.dotSide)
                    .scaleEffect(dot.scale)
            }
        }
        // Quick enough to keep up with speech, slow enough that the dots swell and do not flicker.
        .animation(.easeOut(duration: 0.15), value: level)
        .accessibilityHidden(true)
    }
}

extension View {
    /// Keeps a view in its place, and so keeps its state, while it cannot be seen, touched or read out.
    func concealed(_ isConcealed: Bool) -> some View {
        opacity(isConcealed ? 0 : 1)
            .allowsHitTesting(!isConcealed)
            .accessibilityHidden(isConcealed)
    }
}
