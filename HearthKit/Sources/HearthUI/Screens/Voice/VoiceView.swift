import SwiftUI

struct VoiceView: View {
    let presenter: VoicePresenter

    var body: some View {
        let viewModel = presenter.viewModel
        VStack(spacing: 0) {
            header(viewModel: viewModel)
            VStack(spacing: 28) {
                Button(action: { Task { await presenter.interruptAction() } }, label: {
                    VoiceOrb(state: viewModel.state)
                })
                .buttonStyle(.plain)
                .accessibilityLabel(Strings.interrupt)
                Text(stateTitle(viewModel.state))
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .kerning(1.2)
                    .foregroundStyle(viewModel.state == .unavailable ? HearthColor.danger : HearthColor.pine)
                Text(caption(viewModel: viewModel))
                    .font(HearthFont.spoken)
                    .foregroundStyle(viewModel.caption.isEmpty ? HearthColor.mute : HearthColor.ink)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .lineLimit(7)
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .top)
                    .animation(.easeOut(duration: 0.15), value: viewModel.caption)
            }
            .padding(.horizontal, 28)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            controls(viewModel: viewModel)
        }
        .background(HearthColor.paper.ignoresSafeArea())
        .sensoryFeedback(.impact(weight: .light), trigger: viewModel.state)
        .task { await presenter.startAction() }
    }

    private func header(viewModel: VoiceViewModel) -> some View {
        HStack(spacing: 8) {
            IconButton(systemImage: "chevron.down", label: Strings.endVoice) {
                Task { await presenter.endAction() }
            }
            HStack(spacing: 6) {
                Text(viewModel.modelName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(HearthColor.ink)
                Text(viewModel.voiceName)
                    .font(.footnote)
                    .foregroundStyle(HearthColor.mute)
            }
            .lineLimit(1)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(HearthColor.card, in: Capsule())
            .overlay { Capsule().strokeBorder(HearthColor.line, lineWidth: 1) }
            .frame(maxWidth: .infinity)
            Color.clear
                .frame(width: 40, height: 40)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private func controls(viewModel: VoiceViewModel) -> some View {
        let isMuted = viewModel.state == .muted
        return HStack(spacing: 24) {
            roundButton(
                systemImage: isMuted ? "mic.slash.fill" : "mic.fill",
                label: isMuted ? Strings.unmute : Strings.mute,
                isProminent: false
            ) {
                Task { await presenter.muteAction() }
            }
            .disabled(viewModel.state == .unavailable)
            .opacity(viewModel.state == .unavailable ? 0.4 : 1)
            roundButton(systemImage: "xmark", label: Strings.endVoice, isProminent: true) {
                Task { await presenter.endAction() }
            }
        }
        .padding(.bottom, 28)
    }

    private func roundButton(systemImage: String, label: String, isProminent: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3.weight(.medium))
                .foregroundStyle(isProminent ? Color.white : HearthColor.ink)
                .frame(width: 60, height: 60)
                .background(isProminent ? HearthColor.danger : HearthColor.card, in: Circle())
                .overlay { Circle().strokeBorder(isProminent ? .clear : HearthColor.line, lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func stateTitle(_ state: VoiceStateKind) -> String {
        switch state {
        case .listening:
            Strings.listening
        case .thinking:
            Strings.voiceThinking
        case .speaking:
            Strings.speaking
        case .muted:
            Strings.muted
        case .unavailable:
            Strings.unavailable
        }
    }

    private func caption(viewModel: VoiceViewModel) -> String {
        guard viewModel.caption.isEmpty else {
            return viewModel.caption
        }
        switch viewModel.state {
        case .listening:
            return Strings.voiceHint
        case .muted:
            return Strings.voiceMutedHint
        case .thinking, .speaking, .unavailable:
            return " "
        }
    }
}

/// The glowing orb at the heart of a voice conversation; it breathes faster the busier things are.
private struct VoiceOrb: View {
    let state: VoiceStateKind

    @State private var isExpanded = false

    var body: some View {
        ZStack {
            Circle()
                .fill(HearthColor.pine.opacity(0.06))
                .frame(width: 230, height: 230)
                .scaleEffect(isExpanded ? 1.08 : 0.92)
            Circle()
                .fill(HearthColor.pine.opacity(0.10))
                .frame(width: 190, height: 190)
                .scaleEffect(isExpanded ? 1.06 : 0.95)
            Circle()
                .fill(
                    RadialGradient(
                        colors: Self.orbColors,
                        center: UnitPoint(x: 0.35, y: 0.3),
                        startRadius: 4,
                        endRadius: 130
                    )
                )
                .frame(width: 150, height: 150)
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

    private static let orbColors = [
        Color(lightHex: 0x9FE0CB, darkHex: 0x9FE0CB),
        Color(lightHex: 0x2C6B5A, darkHex: 0x3E8A75),
        Color(lightHex: 0x1B4A3D, darkHex: 0x1B4A3D)
    ]

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
