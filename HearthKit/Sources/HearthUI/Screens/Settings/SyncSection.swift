import HearthDomain
import SwiftUI

/// The row in the settings that leads to the sync page, saying whether sync is on.
struct SyncSection: View {
    let presenter: SettingsPresenter
    /// Opens the page this row leads to.
    let openAction: (SettingsPageKind) -> Void

    var body: some View {
        let isOn = presenter.syncStore.settings.isEnabled
        Section {
            SettingsLinkRow(action: { openAction(.sync) }, label: {
                HStack(spacing: HearthSpacing.s8) {
                    Text(Strings.sync)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(isOn ? Strings.syncOn : Strings.syncOff)
                        .foregroundStyle(HearthColor.mute)
                }
            })
            .accessibilityLabel("\(Strings.sync), \(isOn ? Strings.syncOn : Strings.syncOff)")
        }
    }
}

/// Where the hub is, its access token, the switch, syncing now, and how the last sync went. Everything here takes
/// effect at once.
struct SyncPage: View {
    let presenter: SettingsPresenter

    var body: some View {
        @Bindable var viewModel = presenter.viewModel
        let store = presenter.syncStore
        let canEnable = presenter.canEnableSync
        SettingsPage(title: Strings.sync) {
            SettingsCard(footer: Strings.syncHubFooter) {
                addressField(text: $viewModel.syncAddress)
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
                actionRow(Strings.syncNow, systemImage: "arrow.triangle.2.circlepath") { await presenter.syncNowAction() }
                    .disabled(!store.settings.isEnabled || store.isSyncing)
                Hairline()
                    .padding(.leading, HearthSpacing.s16)
                actionRow(Strings.syncCheck, systemImage: "network") { await presenter.checkHubAction() }
                    .disabled(!canEnable)
                checkResult(viewModel.syncCheck)
            }
            SettingsCard(header: Strings.syncStatus) {
                Text(presenter.syncStatusText)
                    .font(.hearth(.footnote))
                    .foregroundStyle(store.failure == nil ? HearthColor.mute : HearthColor.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, HearthSpacing.s16)
                    .padding(.vertical, HearthSpacing.s12)
                    .accessibilityLabel("\(Strings.syncStatus): \(presenter.syncStatusText)")
            }
        }
        .onDisappear { Task { await presenter.syncAddressAction() } }
    }

    /// The hub's address under a small caption, typed without autocorrection.
    private func addressField(text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: HearthSpacing.s2) {
            Text(Strings.syncHubAddress)
                .font(.hearth(.caption))
                .foregroundStyle(HearthColor.mute)
                .accessibilityHidden(true)
            TextField("https://", text: text)
                .font(.hearth(.body))
                .foregroundStyle(HearthColor.ink)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onSubmit { Task { await presenter.syncAddressAction() } }
                .accessibilityLabel(Strings.syncHubAddress)
        }
        .padding(.horizontal, HearthSpacing.s16)
        .padding(.vertical, HearthSpacing.s10)
    }

    /// A field for a new token, which is never filled with the saved one, and the buttons that keep or forget it.
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

    private func actionRow(_ title: String, systemImage: String, action: @escaping () async -> Void) -> some View {
        Button(action: { Task { await action() } }, label: {
            Label(title, systemImage: systemImage)
                .font(.hearth(.body))
                .foregroundStyle(HearthColor.pine)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, HearthSpacing.s16)
                .padding(.vertical, HearthSpacing.s14)
                .contentShape(Rectangle())
        })
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    /// The outcome of the hub check; nothing until one has been run. Kept in the tree and hidden when there is none.
    private func checkResult(_ check: SyncCheckKind) -> some View {
        let look = CheckLook(check)
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

/// How the outcome of a hub check is drawn.
private struct CheckLook {
    let text: String
    let systemImage: String
    let color: Color

    init(_ check: SyncCheckKind) {
        switch check {
        case .idle:
            (text, systemImage, color) = ("", "circle", HearthColor.mute)
        case .checking:
            (text, systemImage, color) = (Strings.checking, "ellipsis", HearthColor.mute)
        case .succeeded:
            (text, systemImage, color) = (Strings.syncCheckSucceeded, "checkmark.circle.fill", HearthColor.online)
        case .failed(let message):
            (text, systemImage, color) = (message, "exclamationmark.triangle.fill", HearthColor.danger)
        }
    }
}
