import HearthDomain
import SwiftUI

/// The settings sheet: servers, voice, instructions, memory, the lock and the theme.
struct SettingsView: View {
    let presenter: SettingsPresenter

    var body: some View {
        @Bindable var viewModel = presenter.viewModel
        NavigationStack {
            Form {
                Section {
                    addressField(Strings.ollamaAddress, text: $viewModel.ollamaAddress)
                    addressField(Strings.searchAddress, text: $viewModel.searchAddress)
                    addressField(Strings.speechAddress, text: $viewModel.speechAddress)
                        .onSubmit { Task { await presenter.loadVoicesAction() } }
                } header: {
                    Text(Strings.servers)
                } footer: {
                    Text(Strings.serversFooter)
                }
                Section {
                    Toggle(Strings.readPages, isOn: $viewModel.isPageReadingEnabled)
                } header: {
                    Text(Strings.searchLabel)
                } footer: {
                    Text(Strings.readPagesFooter)
                }
                Section {
                    Button(Strings.testConnection) { Task { await presenter.testAction() } }
                        .foregroundStyle(HearthColor.pine)
                    connectionStatus(viewModel.connectionCheck)
                }
                Section(Strings.voice) {
                    voiceControl(voice: $viewModel.voice, voices: viewModel.voices)
                        .onChange(of: viewModel.voice) { Task { await presenter.stopVoicePreviewAction() } }
                    voicePreviewButton(viewModel.voicePreview)
                        .disabled(viewModel.speechAddress.trimmingCharacters(in: .whitespaces).isEmpty)
                    Toggle(Strings.readRepliesAloud, isOn: $viewModel.isAutoReadEnabled)
                }
                Section {
                    TextField(Strings.instructionsPlaceholder, text: $viewModel.customInstructions, axis: .vertical)
                        .lineLimit(3...10)
                        .accessibilityLabel(Strings.instructions)
                    Toggle(Strings.suggestFollowUps, isOn: $viewModel.isFollowUpsEnabled)
                } header: {
                    Text(Strings.instructions)
                } footer: {
                    Text(Strings.instructionsFooter)
                }
                MemorySection(presenter: presenter)
                Section {
                    Toggle(Strings.requireUnlock, isOn: $viewModel.isLockEnabled)
                        .onChange(of: viewModel.isLockEnabled) { Task { await presenter.lockAction() } }
                } header: {
                    Text(Strings.privacy)
                } footer: {
                    Text(Strings.requireUnlockFooter)
                }
                Section(Strings.theme) {
                    Picker(Strings.theme, selection: $viewModel.appearance) {
                        ForEach(AppearanceKind.allCases, id: \.self) { appearance in
                            Text(appearance.title).tag(appearance)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: viewModel.appearance) { presenter.appearanceAction() }
                }
            }
            .scrollContentBackground(.hidden)
            .background(HearthColor.paper)
            .navigationTitle(Strings.settings)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Strings.cancel, action: presenter.cancelAction)
                        .foregroundStyle(HearthColor.mute)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(Strings.done, action: presenter.saveAction)
                        .fontWeight(.semibold)
                        .foregroundStyle(HearthColor.pine)
                }
            }
        }
        .tint(HearthColor.pine)
        .task { await presenter.loadAction() }
    }

    // MARK: Rows

    /// A server address under a small caption, typed without autocorrection.
    private func addressField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: HearthSpacing.s4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(HearthColor.mute)
                .accessibilityHidden(true)
            TextField("https://", text: text)
                .font(.body)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityLabel(title)
        }
    }

    /// The outcome of the connection test. Nothing is shown until one has been run.
    @ViewBuilder
    private func connectionStatus(_ check: ConnectionCheckKind) -> some View {
        switch check {
        case .idle:
            EmptyView()
        case .checking:
            Label(Strings.checking, systemImage: "ellipsis")
                .font(.footnote)
                .foregroundStyle(HearthColor.mute)
        case .succeeded(let modelCount):
            Label(Strings.testSucceeded(modelCount: modelCount), systemImage: "checkmark.circle.fill")
                .font(.footnote)
                .foregroundStyle(HearthColor.online)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.footnote)
                .foregroundStyle(HearthColor.danger)
        }
    }

    /// A picker of the server's voices, or a field for the voice's name when the server has not listed any.
    /// A saved voice the server no longer lists is kept at the head of the picker.
    @ViewBuilder
    private func voiceControl(voice: Binding<String>, voices: [String]) -> some View {
        if voices.isEmpty {
            TextField(Strings.voiceName, text: voice)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityLabel(Strings.voiceName)
        } else {
            Picker(Strings.voice, selection: voice) {
                ForEach(voices.contains(voice.wrappedValue) ? voices : [voice.wrappedValue] + voices, id: \.self) { name in
                    Text(name).tag(name)
                }
            }
        }
    }

    /// Plays a short sample, so a voice can be heard before it is kept.
    private func voicePreviewButton(_ preview: VoicePreviewKind) -> some View {
        let isPlaying = preview == .playing
        return VStack(alignment: .leading, spacing: HearthSpacing.s6) {
            Button(action: { Task { await presenter.previewVoiceAction() } }, label: {
                Label(isPlaying ? Strings.stopVoiceSample : Strings.playVoiceSample, systemImage: isPlaying ? "stop.fill" : "play.fill")
                    .foregroundStyle(HearthColor.pine)
            })
            Label(Strings.voiceSampleFailed, systemImage: "exclamationmark.triangle.fill")
                .font(.footnote)
                .foregroundStyle(HearthColor.danger)
                .opacity(preview == .failed ? 1 : 0)
                .frame(height: preview == .failed ? nil : 0)
                .accessibilityHidden(preview != .failed)
        }
    }
}
