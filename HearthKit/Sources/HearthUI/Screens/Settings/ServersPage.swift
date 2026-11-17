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
                CheckResultLine(outcome: CheckResultLine.OutcomeKind(viewModel.connectionCheck))
            }
        }
        .onDisappear { Task { await presenter.serverAddressesEditedAction() } }
    }

    private var divider: some View {
        Hairline()
            .padding(.leading, HearthSpacing.s16)
    }

    private func addressField(_ title: String, text: Binding<String>) -> some View {
        AddressFieldRow(title: title, text: text) { Task { await presenter.serverAddressesEditedAction() } }
    }

    private var testButton: some View {
        SettingsActionRow(title: Strings.testConnection, systemImage: "network") { Task { await presenter.testAction() } }
            .disabled(presenter.viewModel.connectionCheck == .checking)
    }
}

private extension CheckResultLine.OutcomeKind {
    init(_ check: ConnectionCheckKind) {
        switch check {
        case .idle:
            self = .idle
        case .checking:
            self = .checking
        case .succeeded(let modelCount):
            self = .succeeded(Strings.testSucceeded(modelCount: modelCount))
        case .failed(let message):
            self = .failed(message)
        }
    }
}
