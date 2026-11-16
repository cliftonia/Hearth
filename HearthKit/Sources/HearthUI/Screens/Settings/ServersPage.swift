import SwiftUI

/// Where the four servers are, a test of the chat server directly beneath them, and which of them is required.
/// An address is kept, and its server asked afresh, once its field is left or the page closes; never per letter.
struct ServersPage: View {
    let presenter: SettingsPresenter

    var body: some View {
        @Bindable var viewModel = presenter.viewModel
        SettingsPage(title: Strings.servers) {
            SettingsCard(footer: Strings.serversFooter) {
                addressField(Strings.ollamaAddress, text: $viewModel.ollamaAddress)
                divider
                addressField(Strings.searchAddress, text: $viewModel.searchAddress)
                divider
                addressField(Strings.speechAddress, text: $viewModel.speechAddress)
                divider
                addressField(Strings.imageAddress, text: $viewModel.imageAddress)
                divider
                testButton
                connectionStatus(viewModel.connectionCheck)
            }
        }
        .onDisappear { Task { await presenter.serverAddressesEditedAction() } }
    }

    private var divider: some View {
        Hairline()
            .padding(.leading, HearthSpacing.s16)
    }

    /// A server address under a small caption, typed without autocorrection.
    private func addressField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: HearthSpacing.s2) {
            Text(title)
                .font(.hearth(.caption))
                .foregroundStyle(HearthColor.mute)
                .accessibilityHidden(true)
            TextField("https://", text: text)
                .font(.hearth(.body))
                .foregroundStyle(HearthColor.ink)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityLabel(title)
                .keepOnLeaving { Task { await presenter.serverAddressesEditedAction() } }
        }
        .padding(.horizontal, HearthSpacing.s16)
        .padding(.vertical, HearthSpacing.s10)
    }

    private var testButton: some View {
        Button(action: { Task { await presenter.testAction() } }, label: {
            Label(Strings.testConnection, systemImage: "network")
                .font(.hearth(.body))
                .foregroundStyle(HearthColor.pine)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, HearthSpacing.s16)
                .padding(.vertical, HearthSpacing.s14)
                .contentShape(Rectangle())
        })
        .buttonStyle(.plain)
        .disabled(presenter.viewModel.connectionCheck == .checking)
        .accessibilityLabel(Strings.testConnection)
    }

    /// The outcome of the test; nothing until one has been run. Kept in the tree and hidden when there is none.
    private func connectionStatus(_ check: ConnectionCheckKind) -> some View {
        let look = ConnectionLook(check)
        let isShown = check != .idle
        return Label(look.text, systemImage: look.systemImage)
            .font(.hearth(.footnote))
            .foregroundStyle(look.color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, HearthSpacing.s16)
            .padding(.bottom, isShown ? HearthSpacing.s12 : 0)
            .frame(height: isShown ? nil : 0)
            .opacity(isShown ? 1 : 0)
            .accessibilityHidden(!isShown)
    }
}

/// How the outcome of a connection test is drawn.
private struct ConnectionLook {
    let text: String
    let systemImage: String
    let color: Color

    init(_ check: ConnectionCheckKind) {
        switch check {
        case .idle:
            (text, systemImage, color) = ("", "circle", HearthColor.mute)
        case .checking:
            (text, systemImage, color) = (Strings.checking, "ellipsis", HearthColor.mute)
        case .succeeded(let modelCount):
            (text, systemImage, color) = (Strings.testSucceeded(modelCount: modelCount), "checkmark.circle.fill", HearthColor.online)
        case .failed(let message):
            (text, systemImage, color) = (message, "exclamationmark.triangle.fill", HearthColor.danger)
        }
    }
}
