import SwiftUI

/// What stands in front of the conversations while the app is locked or out of sight.
struct LockView: View {
    private static let buttonVerticalPadding: CGFloat = 11

    let presenter: LockPresenter

    var body: some View {
        let viewModel = presenter.viewModel
        VStack(spacing: HearthSpacing.s18) {
            HearthMark(sideLength: 64)
            Text(Strings.brand)
                .font(HearthFont.display)
                .foregroundStyle(HearthColor.ink)
            Button(action: { Task { await presenter.unlockAction() } }, label: {
                Label(Strings.unlock, systemImage: "lock.open")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(HearthColor.onPine)
                    .padding(.horizontal, HearthSpacing.s20)
                    .padding(.vertical, Self.buttonVerticalPadding)
                    .background(HearthColor.pine, in: Capsule())
            })
            .buttonStyle(.plain)
            .disabled(viewModel.isAuthenticating)
            .opacity(viewModel.isLocked ? 1 : 0)
            .accessibilityHidden(!viewModel.isLocked)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(HearthColor.paper.ignoresSafeArea())
    }
}
