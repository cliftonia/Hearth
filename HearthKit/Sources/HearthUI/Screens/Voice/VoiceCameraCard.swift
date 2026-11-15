import SwiftUI

/// The camera's live picture in a voice conversation, with the button that changes which camera is used.
struct VoiceCameraCard: View {
    let presenter: VoicePresenter

    var body: some View {
        let viewModel = presenter.viewModel
        // A device with one camera has nothing to change to, and neither has a camera that is not yet on.
        let canFlip = viewModel.cameraAvailability.canFlip && viewModel.camera.phase == .on
        let shape = RoundedRectangle(cornerRadius: HearthRadius.preview, style: .continuous)
        CameraPreviewSurface(layer: presenter.cameraPreviewLayer)
            .accessibilityElement()
            .accessibilityLabel(Strings.cameraPreview)
            .accessibilityAddTraits(.isImage)
            .clipShape(shape)
            .surface(shape)
            .overlay(alignment: .topTrailing) {
                Button(action: { Task { await presenter.flipCameraAction() } }, label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(HearthFont.icon)
                        .foregroundStyle(HearthColor.ink)
                        .frame(width: HearthSize.iconButton, height: HearthSize.iconButton)
                        .surface(Circle(), fill: HearthColor.card.opacity(0.9))
                })
                .buttonStyle(.plain)
                .accessibilityLabel(Strings.cameraFlip)
                .padding(HearthSpacing.s10)
                .opacity(canFlip ? 1 : 0)
                .allowsHitTesting(canFlip)
                .accessibilityHidden(!canFlip)
            }
    }
}
