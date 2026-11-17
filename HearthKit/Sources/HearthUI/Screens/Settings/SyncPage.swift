import HearthDomain
import SwiftUI

/// Where the hub is, its access key, the switch, syncing now, and how the last sync went. Everything here takes
/// effect at once.
struct SyncPage: View {
    let presenter: SettingsPresenter

    var body: some View {
        @Bindable var viewModel = presenter.viewModel
        let store = presenter.syncStore
        let canEnable = presenter.canEnableSync
        SettingsPage(title: Strings.sync) {
            SettingsCard(footer: Strings.syncHubFooter) {
                AddressFieldRow(title: Strings.syncHubAddress, text: $viewModel.syncAddress) { Task { await presenter.syncAddressAction() } }
                Hairline()
                    .padding(.leading, HearthSpacing.s16)
                tokenField(text: $viewModel.syncTokenDraft, hasToken: store.hasToken)
            }
            SettingsCard(footer: canEnable ? Strings.syncSwitchDetail : Strings.syncNeedsAddress) {
                SettingsSwitchRow(title: Strings.syncSwitch, isOn: $viewModel.isSyncEnabled)
                    .disabled(!canEnable)
                    .onChange(of: viewModel.isSyncEnabled) { Task { await presenter.syncEnabledAction() } }
            }
            SettingsCard {
                SettingsActionRow(title: Strings.syncNow, systemImage: "arrow.triangle.2.circlepath") { Task { await presenter.syncNowAction() } }
                    .disabled(!store.settings.isEnabled || store.isSyncing)
                Hairline()
                    .padding(.leading, HearthSpacing.s16)
                SettingsActionRow(title: Strings.syncCheck, systemImage: "network") { Task { await presenter.checkHubAction() } }
                    .disabled(!canEnable)
                CheckResultLine(outcome: CheckResultLine.OutcomeKind(viewModel.syncCheck))
            }
            SettingsCard(header: Strings.syncStatus) {
                Text(presenter.syncStatusText)
                    .font(.hearth(.footnote))
                    .foregroundStyle(store.failure == nil ? HearthColor.mute : HearthColor.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, HearthSpacing.s16)
                    .padding(.vertical, HearthSpacing.s12)
                    .accessibilityLabel(Strings.syncStatusLabel(presenter.syncStatusText))
            }
        }
        .onDisappear { Task { await presenter.syncAddressAction() } }
    }

    /// A field for a new access key, which is never filled with the saved one, and the buttons that keep or forget it.
    private func tokenField(text: Binding<String>, hasToken: Bool) -> some View {
        VStack(alignment: .leading, spacing: HearthSpacing.s8) {
            Text(Strings.syncToken)
                .font(.hearth(.caption))
                .foregroundStyle(HearthColor.mute)
                .accessibilityHidden(true)
            SecureField(hasToken ? Strings.syncTokenSavedPlaceholder : Strings.syncTokenPlaceholder, text: text)
                .font(.hearth(.body))
                .foregroundStyle(HearthColor.ink)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onSubmit { Task { await presenter.saveSyncTokenAction() } }
                .accessibilityLabel(Strings.syncToken)
            HStack(spacing: HearthSpacing.s16) {
                Button(Strings.syncSaveToken) { Task { await presenter.saveSyncTokenAction() } }
                    .disabled(text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel(Strings.syncSaveToken)
                Button(Strings.syncRemoveToken, role: .destructive, action: presenter.removeSyncTokenAction)
                    .disabled(!hasToken)
                    .accessibilityLabel(Strings.syncRemoveToken)
            }
            .font(.hearth(.subheadline).weight(.medium))
            .buttonStyle(.borderless)
            Text(Strings.syncTokenFooter)
                .font(.hearth(.footnote))
                .foregroundStyle(HearthColor.mute)
        }
        .padding(.horizontal, HearthSpacing.s16)
        .padding(.vertical, HearthSpacing.s10)
    }
}

private extension CheckResultLine.OutcomeKind {
    init(_ check: SyncCheckKind) {
        switch check {
        case .idle:
            self = .idle
        case .checking:
            self = .checking
        case .succeeded:
            self = .succeeded(Strings.syncCheckSucceeded)
        case .failed(let message):
            self = .failed(message)
        }
    }
}
