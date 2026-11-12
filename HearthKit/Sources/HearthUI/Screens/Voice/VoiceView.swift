import SwiftUI

/// A hands-free conversation: the orb, what is being heard or said, and the mute and end buttons.
struct VoiceView: View {
    /// Room for the caption to grow without the orb moving.
    private static let captionMinimumHeight: CGFloat = 120
    private static let captionLineLimit = 7

    let presenter: VoicePresenter

    var body: some View {
        let viewModel = presenter.viewModel
        VStack(spacing: 0) {
            header(viewModel: viewModel)
            VStack(spacing: HearthSpacing.s28) {
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
                    .lineLimit(Self.captionLineLimit)
                    .frame(maxWidth: .infinity, minHeight: Self.captionMinimumHeight, alignment: .top)
                    .animation(.easeOut(duration: 0.15), value: viewModel.caption)
            }
            .padding(.horizontal, HearthSpacing.s28)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            controls(viewModel: viewModel)
        }
        .background(HearthColor.paper.ignoresSafeArea())
        .sensoryFeedback(.impact(weight: .light), trigger: viewModel.state)
        .task { await presenter.startAction() }
    }

    // MARK: Header and controls

    /// A way out, and a pill naming the model and the voice.
    private func header(viewModel: VoiceViewModel) -> some View {
        HStack(spacing: HearthSpacing.s8) {
            IconButton(systemImage: "chevron.down", label: Strings.endVoice) {
                Task { await presenter.endAction() }
            }
            HStack(spacing: HearthSpacing.s6) {
                Text(viewModel.modelName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(HearthColor.ink)
                Text(viewModel.voiceName)
                    .font(.footnote)
                    .foregroundStyle(HearthColor.mute)
            }
            .lineLimit(1)
            .padding(.horizontal, HearthSpacing.s14)
            .padding(.vertical, HearthSpacing.s8)
            .capsuleSurface()
            .frame(maxWidth: .infinity)
            // Balances the button on the other side, so the pill sits in the middle.
            Color.clear
                .frame(width: HearthSize.iconButton, height: HearthSize.iconButton)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, HearthSpacing.s8)
        .padding(.vertical, HearthSpacing.s4)
    }

    private func controls(viewModel: VoiceViewModel) -> some View {
        let isMuted = viewModel.state == .muted
        return HStack(spacing: HearthSpacing.s24) {
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
        .padding(.bottom, HearthSpacing.s28)
    }

    /// A large round button: outlined when quiet, filled with the danger colour when it ends the conversation.
    private func roundButton(systemImage: String, label: String, isProminent: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3.weight(.medium))
                .foregroundStyle(isProminent ? HearthColor.onDanger : HearthColor.ink)
                .frame(width: HearthSize.voiceButton, height: HearthSize.voiceButton)
                .surface(Circle(), fill: isProminent ? HearthColor.danger : HearthColor.card, border: isProminent ? .clear : HearthColor.line)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: Words

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

    /// The caption, or a hint when there is none. A single space keeps the line's height while there is nothing to say.
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
