import HearthDomain
import SwiftUI

/// Memory, follow-up questions, web search and scheduled tasks.
struct SettingsChatsSection: View {
    let presenter: SettingsPresenter
    let tasksPresenter: ScheduledTasksPresenter
    let openAction: (SettingsPageKind) -> Void

    var body: some View {
        @Bindable var viewModel = presenter.viewModel
        Section {
            SettingsStatusRow(title: Strings.memory, status: presenter.memoryStatus) { openAction(.memories) }
            Toggle(isOn: $viewModel.isFollowUpsEnabled) {
                VStack(alignment: .leading, spacing: HearthSpacing.s2) {
                    Text(Strings.suggestFollowUps)
                        .font(.hearth(.body))
                        .foregroundStyle(HearthColor.ink)
                    Text(Strings.followUpsFooter)
                        .font(.hearth(.footnote))
                        .foregroundStyle(HearthColor.mute)
                }
            }
            .onChange(of: viewModel.isFollowUpsEnabled) { presenter.keepAction() }
            .accessibilityLabel(Strings.suggestFollowUps)
            .accessibilityHint(Strings.followUpsFooter)
            SettingsStatusRow(title: Strings.searchLabel, status: presenter.webSearchStatus) { openAction(.webSearch) }
            SettingsStatusRow(title: Strings.tasks, status: tasksPresenter.rowStatus) { openAction(.tasks) }
        } header: {
            SettingsSectionHeader(title: Strings.settingsChats)
        }
    }
}

/// The voice replies are read in, and the model pictures are made with.
struct SettingsVoicePicturesSection: View {
    let presenter: SettingsPresenter
    let openAction: (SettingsPageKind) -> Void

    var body: some View {
        Section {
            SettingsStatusRow(title: Strings.voice, status: presenter.voiceStatus, isEnabled: presenter.hasSpeechServer) {
                openAction(.voice)
            }
            SettingsStatusRow(title: Strings.pictures, status: presenter.picturesStatus) { openAction(.pictures) }
        } header: {
            SettingsSectionHeader(title: Strings.settingsVoicePictures)
        }
    }
}

/// The theme, vibration where the device has it, and the lock.
struct SettingsAppearancePrivacySection: View {
    let presenter: SettingsPresenter

    var body: some View {
        @Bindable var viewModel = presenter.viewModel
        Section {
            HStack(spacing: HearthSpacing.s12) {
                Text(Strings.theme)
                    .font(.hearth(.body))
                    .foregroundStyle(HearthColor.ink)
                    .accessibilityHidden(true)
                Picker(Strings.theme, selection: $viewModel.appearance) {
                    ForEach(AppearanceKind.allCases, id: \.self) { appearance in
                        Text(appearance.title).tag(appearance)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel(Strings.theme)
                .onChange(of: viewModel.appearance) { presenter.keepAction() }
            }
            // An iPad or a Mac has nothing to vibrate with, so the switch would do nothing there.
            if Haptics.isAvailable {
                Toggle(Strings.vibration, isOn: $viewModel.isHapticsEnabled)
                    .font(.hearth(.body))
                    .onChange(of: viewModel.isHapticsEnabled) { presenter.keepAction() }
                    .accessibilityLabel(Strings.vibration)
            }
            Toggle(viewModel.unlockWording.requireTitle, isOn: $viewModel.isLockEnabled)
                .font(.hearth(.body))
                .onChange(of: viewModel.isLockEnabled) { Task { await presenter.lockAction() } }
                .accessibilityLabel(viewModel.unlockWording.requireTitle)
        } header: {
            SettingsSectionHeader(title: Strings.settingsAppearancePrivacy)
        } footer: {
            Text(Strings.requireUnlockFooter)
        }
    }
}

/// Where the servers are, and sync.
struct SettingsServersSyncSection: View {
    let presenter: SettingsPresenter
    let openAction: (SettingsPageKind) -> Void

    var body: some View {
        Section {
            SettingsStatusRow(title: Strings.servers, status: presenter.serversStatus) { openAction(.servers) }
            SettingsStatusRow(title: Strings.sync, status: presenter.syncRowStatus) { openAction(.sync) }
            // A "Cloud providers" row, leading to the providers of cloud models, will go here.
        } header: {
            SettingsSectionHeader(title: Strings.settingsServersSync)
        }
    }
}

/// Erasing everything on the device, last on the list, with what went wrong beneath it if something did.
/// What is offered is to erase what the device holds; nothing on the hub is deleted.
struct SettingsEraseSection: View {
    let presenter: SettingsPresenter

    var body: some View {
        @Bindable var viewModel = presenter.viewModel
        let error = viewModel.eraseError
        Section {
            Button(Strings.eraseAll, role: .destructive) { viewModel.isConfirmingErase = true }
                .font(.hearth(.body))
                .foregroundStyle(HearthColor.danger)
                .accessibilityLabel(Strings.eraseAll)
        } footer: {
            VStack(alignment: .leading, spacing: HearthSpacing.s8) {
                Text(Strings.eraseAllFooter)
                Label(error ?? "", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(HearthColor.danger)
                    .opacity(error == nil ? 0 : 1)
                    .frame(height: error == nil ? 0 : nil)
                    .accessibilityHidden(error == nil)
            }
        }
        .confirmationDialog(Strings.eraseAllQuestion, isPresented: $viewModel.isConfirmingErase, titleVisibility: .visible) {
            Button(Strings.eraseAllConfirm, role: .destructive) {
                Haptics.play(.warning)
                Task { await presenter.eraseAction() }
            }
            Button(Strings.cancel, role: .cancel) {}
        } message: {
            Text(Strings.eraseAllMessage)
        }
    }
}
