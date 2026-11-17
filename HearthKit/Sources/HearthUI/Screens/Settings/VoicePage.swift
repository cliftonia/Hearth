import SwiftUI

/// The voice replies are read in, a sample of it, and whether replies are read aloud as they arrive.
struct VoicePage: View {
    let presenter: SettingsPresenter

    var body: some View {
        @Bindable var viewModel = presenter.viewModel
        SettingsPage(title: Strings.voice) {
            SettingsCard {
                voiceControl(voice: $viewModel.voice, voices: viewModel.voices)
                    .onChange(of: viewModel.voice) { Task { await presenter.voiceChangedAction() } }
                Hairline()
                    .padding(.leading, HearthSpacing.s16)
                previewButton(viewModel.voicePreview)
                    .disabled(!presenter.hasSpeechServer)
                Hairline()
                    .padding(.leading, HearthSpacing.s16)
                SettingsSwitchRow(title: Strings.readRepliesAloud, isOn: $viewModel.isAutoReadEnabled)
                    .onChange(of: viewModel.isAutoReadEnabled) { presenter.keepAction() }
                    .accessibilityLabel(Strings.readRepliesAloud)
            }
        }
        .onDisappear {
            presenter.keepAction()
            Task { await presenter.stopVoicePreviewAction() }
        }
    }

    /// A menu of the server's voices, or a field for the voice's name when the server has not listed any.
    /// A saved voice the server no longer lists is kept at the head of the menu.
    @ViewBuilder
    private func voiceControl(voice: Binding<String>, voices: [String]) -> some View {
        if voices.isEmpty {
            VStack(alignment: .leading, spacing: HearthSpacing.s2) {
                Text(Strings.voiceName)
                    .font(.hearth(.caption))
                    .foregroundStyle(HearthColor.mute)
                    .accessibilityHidden(true)
                TextField(Strings.voiceName, text: voice)
                    .font(.hearth(.body))
                    .foregroundStyle(HearthColor.ink)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityLabel(Strings.voiceName)
                    .keepOnLeaving(presenter.keepAction)
            }
            .padding(.horizontal, HearthSpacing.s16)
            .padding(.vertical, HearthSpacing.s10)
        } else {
            HStack(spacing: HearthSpacing.s12) {
                Text(Strings.voice)
                    .font(.hearth(.body))
                    .foregroundStyle(HearthColor.ink)
                    .accessibilityHidden(true)
                Picker(Strings.voice, selection: voice) {
                    ForEach(voices.contains(voice.wrappedValue) ? voices : [voice.wrappedValue] + voices, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .trailing)
                .accessibilityLabel(Strings.voice)
            }
            .padding(.horizontal, HearthSpacing.s16)
            .padding(.vertical, HearthSpacing.s8)
        }
    }

    /// Plays a short sample, so a voice can be heard before it is kept, and says so if it could not be played.
    private func previewButton(_ preview: VoicePreviewKind) -> some View {
        let isPlaying = preview == .playing
        let title = isPlaying ? Strings.stopVoiceSample : Strings.playVoiceSample
        return VStack(alignment: .leading, spacing: HearthSpacing.s6) {
            Button(action: { Task { await presenter.previewVoiceAction() } }, label: {
                Label(title, systemImage: isPlaying ? "stop.fill" : "play.fill")
                    .font(.hearth(.body))
                    .foregroundStyle(HearthColor.pine)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            })
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            Label(Strings.voiceSampleFailed, systemImage: "exclamationmark.triangle.fill")
                .font(.hearth(.footnote))
                .foregroundStyle(HearthColor.danger)
                .folded(preview != .failed)
        }
        .padding(.horizontal, HearthSpacing.s16)
        .padding(.vertical, HearthSpacing.s14)
    }
}
