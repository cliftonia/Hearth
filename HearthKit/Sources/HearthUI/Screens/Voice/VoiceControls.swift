import HearthDomain
import SwiftUI
import UIKit

/// The buttons along the bottom of a voice conversation: the camera, mute and end, with whatever has to be said
/// about the camera above them.
struct VoiceControls: View {
    /// The widest the camera's notices grow, so that they stay readable on an iPad.
    private static let noticeMaximumWidth: CGFloat = 520

    let presenter: VoicePresenter

    @Environment(\.openURL) private var openURL

    var body: some View {
        let viewModel = presenter.viewModel
        let isMuted = viewModel.state == .muted
        VStack(spacing: HearthSpacing.s16) {
            cameraNotice(viewModel: viewModel)
            HStack(spacing: HearthSpacing.s24) {
                // A device's cameras do not come and go, so the button is either there for good or not at all.
                if viewModel.cameraControl != .hidden {
                    cameraButton(viewModel: viewModel)
                }
                VoiceRoundButton(systemImage: isMuted ? "mic.slash.fill" : "mic.fill", label: isMuted ? Strings.unmute : Strings.mute, style: .quiet) {
                    Task { await presenter.muteAction() }
                }
                .disabled(viewModel.state == .unavailable)
                .opacity(viewModel.state == .unavailable ? 0.4 : 1)
                VoiceRoundButton(systemImage: "xmark", label: Strings.endVoice, style: .ending) {
                    Task { await presenter.endAction() }
                }
            }
        }
        .padding(.horizontal, HearthSpacing.s28)
        .padding(.bottom, HearthSpacing.s28)
    }

    // MARK: Camera

    private func cameraButton(viewModel: VoiceViewModel) -> some View {
        let isOn = viewModel.camera.phase != .off
        let isEnabled = viewModel.cameraControl == .enabled
        return VoiceRoundButton(
            systemImage: isOn ? "video.fill" : "video",
            label: isOn ? Strings.cameraTurnOff : Strings.cameraTurnOn,
            style: isOn ? .switchedOn : .quiet
        ) {
            Haptics.play(.light)
            Task { await presenter.cameraAction() }
        }
        .accessibilityHint(isEnabled ? Strings.cameraHint : Strings.cameraModelCannotSee)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
    }

    /// Why the camera is off when the user would expect otherwise. Each line keeps its place in the view and is
    /// folded away while it has nothing to say.
    private func cameraNotice(viewModel: VoiceViewModel) -> some View {
        let notice = viewModel.camera.notice
        let cannotSee = viewModel.cameraControl == .disabled
        return VStack(spacing: 0) {
            Text(Strings.cameraModelCannotSee)
                .font(.hearth(.footnote))
                .foregroundStyle(HearthColor.mute)
                .multilineTextAlignment(.center)
                .folded(!cannotSee)
            PermissionNotice(systemImage: "video.slash", message: Strings.cameraDenied, actionTitle: Strings.cameraOpenSettings) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            .folded(notice != .permissionRefused)
            PermissionNotice(systemImage: "video.slash", message: Strings.cameraUnavailable, actionTitle: nil, action: {})
                .folded(notice != .unavailable)
        }
        .frame(maxWidth: Self.noticeMaximumWidth)
        .animation(.snappy, value: notice)
    }
}

/// How a round button of the voice screen is drawn.
enum VoiceRoundButtonStyleKind: Hashable {
    /// Outlined, for something that can be done.
    case quiet
    /// Filled softly with the brand colour, for something that is switched on.
    case switchedOn
    /// Filled with the danger colour, for the button that ends the conversation.
    case ending
}

/// A large round button holding one symbol.
struct VoiceRoundButton: View {
    let systemImage: String
    /// What VoiceOver reads, since the button shows no text.
    let label: String
    let style: VoiceRoundButtonStyleKind
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.hearth(.title3).weight(.medium))
                .foregroundStyle(symbolColor)
                .frame(width: HearthSize.voiceButton, height: HearthSize.voiceButton)
                .surface(Circle(), fill: fillColor, border: borderColor)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var symbolColor: Color {
        switch style {
        case .quiet:
            HearthColor.ink
        case .switchedOn:
            HearthColor.pine
        case .ending:
            HearthColor.onDanger
        }
    }

    private var fillColor: Color {
        switch style {
        case .quiet:
            HearthColor.card
        case .switchedOn:
            HearthColor.pineSoft
        case .ending:
            HearthColor.danger
        }
    }

    private var borderColor: Color {
        switch style {
        case .quiet:
            HearthColor.line
        case .switchedOn:
            HearthColor.pine
        case .ending:
            .clear
        }
    }
}

private extension View {
    /// Keeps the view in place but folds it to nothing, unseen, untouchable and unread, while it has nothing to say.
    func folded(_ isFolded: Bool) -> some View {
        opacity(isFolded ? 0 : 1)
            .frame(height: isFolded ? 0 : nil, alignment: .top)
            .clipped()
            .allowsHitTesting(!isFolded)
            .accessibilityHidden(isFolded)
    }
}
