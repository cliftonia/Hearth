import SwiftUI

/// A hands-free conversation: the orb, what is being heard or said, the camera's picture when it is on, and the
/// camera, mute and end buttons.
struct VoiceView: View {
    /// Room for the caption to grow without the orb moving, and what it is cut to while the camera's picture
    /// takes part of the screen.
    private static let captionMinimumHeight: CGFloat = 120
    private static let captionLineLimit = 7
    private static let captionMinimumHeightBesideCamera: CGFloat = 64
    private static let captionLineLimitBesideCamera = 3

    let presenter: VoicePresenter

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        let viewModel = presenter.viewModel
        VStack(spacing: 0) {
            header(viewModel: viewModel)
            GeometryReader { geometry in
                conversation(viewModel: viewModel, in: geometry.size)
            }
            VoiceControls(presenter: presenter)
        }
        .background(HearthColor.paper.ignoresSafeArea())
        .haptic(.light, trigger: viewModel.state)
        .task { await presenter.startAction() }
        // The camera is only ever on while this screen is in front of the user.
        .onChange(of: scenePhase) {
            if scenePhase != .active {
                Task { await presenter.leftForegroundAction(isOffScreen: scenePhase == .background) }
            }
        }
        .onDisappear { Task { await presenter.closedAction() } }
    }

    // MARK: The conversation

    /// The camera's picture, the orb, the state and the caption, in the space between the header and the buttons.
    private func conversation(viewModel: VoiceViewModel, in available: CGSize) -> some View {
        let showsCamera = viewModel.camera.isPreviewShown
        let cardSize = VoiceCameraLayout.cardSize(in: available, margin: HearthSpacing.s28)
        let orbSide = VoiceOrb.outerHaloDiameter * (showsCamera ? VoiceCameraLayout.orbScale : 1)
        return VStack(spacing: 0) {
            // The card keeps its place in the view and is folded away while the camera is off.
            VoiceCameraCard(presenter: presenter)
                .frame(width: cardSize.width, height: cardSize.height)
                .frame(height: showsCamera ? cardSize.height : 0, alignment: .top)
                .clipped()
                .opacity(showsCamera ? 1 : 0)
                .allowsHitTesting(showsCamera)
                .accessibilityHidden(!showsCamera)
                .padding(.bottom, showsCamera ? HearthSpacing.s16 : 0)
            VStack(spacing: showsCamera ? HearthSpacing.s16 : HearthSpacing.s28) {
                Button(action: { Task { await presenter.interruptAction() } }, label: {
                    VoiceOrb(state: viewModel.state)
                        .scaleEffect(showsCamera ? VoiceCameraLayout.orbScale : 1)
                        .frame(width: orbSide, height: orbSide)
                })
                .buttonStyle(.plain)
                .accessibilityLabel(Strings.interrupt)
                Text(stateTitle(viewModel.state))
                    .font(.hearth(.caption).weight(.semibold))
                    .textCase(.uppercase)
                    .kerning(1.2)
                    .foregroundStyle(viewModel.state == .unavailable ? HearthColor.danger : HearthColor.pine)
                Text(caption(viewModel: viewModel))
                    .font(HearthFont.spoken)
                    .foregroundStyle(viewModel.caption.isEmpty ? HearthColor.mute : HearthColor.ink)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .lineLimit(showsCamera ? Self.captionLineLimitBesideCamera : Self.captionLineLimit)
                    .frame(
                        maxWidth: .infinity,
                        minHeight: showsCamera ? Self.captionMinimumHeightBesideCamera : Self.captionMinimumHeight,
                        alignment: .top
                    )
                    .animation(.easeOut(duration: 0.15), value: viewModel.caption)
            }
        }
        .padding(.horizontal, HearthSpacing.s28)
        .frame(width: available.width, height: available.height)
        .animation(.snappy(duration: 0.3), value: showsCamera)
    }

    // MARK: Header

    /// A way out, and a pill naming the model and the voice.
    private func header(viewModel: VoiceViewModel) -> some View {
        HStack(spacing: HearthSpacing.s8) {
            IconButton(systemImage: "chevron.down", label: Strings.endVoice) {
                Task { await presenter.endAction() }
            }
            HStack(spacing: HearthSpacing.s6) {
                Text(viewModel.modelName)
                    .font(.hearth(.subheadline).weight(.semibold))
                    .foregroundStyle(HearthColor.ink)
                Text(viewModel.voiceName)
                    .font(.hearth(.footnote))
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
