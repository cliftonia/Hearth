import HearthDomain
import SwiftUI

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
                    Button(Strings.testConnection) { Task { await presenter.testAction() } }
                        .foregroundStyle(HearthColor.pine)
                    connectionStatus(viewModel.connectionCheck)
                }
                Section(Strings.voice) {
                    voiceControl(voice: $viewModel.voice, voices: viewModel.voices)
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

    private func addressField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
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
}
