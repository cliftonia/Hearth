import SwiftUI

/// Whether a web search reads the pages it finds or only their snippets.
struct WebSearchPage: View {
    let presenter: SettingsPresenter

    var body: some View {
        @Bindable var viewModel = presenter.viewModel
        SettingsPage(title: Strings.searchLabel) {
            SettingsCard(footer: Strings.readPagesFooter) {
                SettingsSwitchRow(title: Strings.readPages, isOn: $viewModel.isPageReadingEnabled)
                    .onChange(of: viewModel.isPageReadingEnabled) { presenter.keepAction() }
                    .accessibilityLabel(Strings.readPages)
            }
        }
    }
}
