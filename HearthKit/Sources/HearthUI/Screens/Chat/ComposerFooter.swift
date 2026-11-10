import PhotosUI
import SwiftUI

/// Where a message is written: text, photos, the search toggle, dictation and send.
struct ComposerFooter: View {
    let presenter: ChatPresenter

    @State private var pickedItems: [PhotosPickerItem] = []
    @State private var sendCount = 0
    @FocusState private var isFocused: Bool

    var body: some View {
        @Bindable var viewModel = presenter.viewModel
        VStack(alignment: .leading, spacing: 10) {
            if !viewModel.pendingImagesJPEG.isEmpty {
                PhotoStrip(imagesJPEG: viewModel.pendingImagesJPEG, sideLength: 64, removeAction: presenter.removeImageAction(at:))
            }
            TextField(placeholder, text: $viewModel.draft, axis: .vertical)
                .lineLimit(1...6)
                .font(.body)
                .foregroundStyle(HearthColor.ink)
                .tint(HearthColor.pine)
                .focused($isFocused)
                .padding(.horizontal, 4)
            HStack(spacing: 8) {
                attachButton
                searchToggle
                    .opacity(presenter.isSearchAvailable ? 1 : 0)
                    .accessibilityHidden(!presenter.isSearchAvailable)
                dictationButton
                    .frame(maxWidth: .infinity, alignment: .trailing)
                primaryButton
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(HearthColor.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(HearthColor.line, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 2)
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .sensoryFeedback(.impact(weight: .light), trigger: sendCount)
        .onChange(of: pickedItems) {
            let items = pickedItems
            guard !items.isEmpty else {
                return
            }
            pickedItems = []
            Task { presenter.addImagesAction(await PhotoLoader.jpegData(from: items)) }
        }
    }

    private var placeholder: String {
        presenter.viewModel.selectedModel.map { Strings.messageModel($0.displayName) } ?? Strings.composerPlaceholder
    }

    private var attachButton: some View {
        let canSee = presenter.viewModel.selectedModel?.canSee == true
        return PhotosPicker(selection: $pickedItems, maxSelectionCount: 4, matching: .images) {
            Image(systemName: "plus")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(HearthColor.mute)
                .frame(width: 34, height: 32)
                .overlay { Capsule().strokeBorder(HearthColor.line, lineWidth: 1) }
        }
        .disabled(!canSee)
        .opacity(canSee ? 1 : 0.4)
        .accessibilityLabel(Strings.attach)
    }

    private var searchToggle: some View {
        let isOn = presenter.viewModel.isSearchEnabled
        return Button(action: presenter.toggleSearchAction) {
            HStack(spacing: 5) {
                Image(systemName: "globe")
                    .font(.footnote.weight(.medium))
                Text(Strings.search)
                    .font(.footnote.weight(isOn ? .semibold : .regular))
            }
            .foregroundStyle(isOn ? HearthColor.pine : HearthColor.mute)
            .padding(.horizontal, 11)
            .frame(height: 32)
            .background(isOn ? HearthColor.pineSoft : .clear, in: Capsule())
            .overlay { Capsule().strokeBorder(isOn ? .clear : HearthColor.line, lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Strings.searchLabel)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private var dictationButton: some View {
        let isDictating = presenter.viewModel.isDictating
        return Button(action: { Task { await presenter.dictationAction() } }, label: {
            Image(systemName: isDictating ? "mic.fill" : "mic")
                .font(.footnote.weight(.medium))
                .foregroundStyle(isDictating ? HearthColor.danger : HearthColor.mute)
                .frame(width: 34, height: 32)
                .overlay { Capsule().strokeBorder(isDictating ? HearthColor.danger : HearthColor.line, lineWidth: 1) }
        })
        .buttonStyle(.plain)
        .accessibilityLabel(isDictating ? Strings.stopDictation : Strings.dictate)
    }

    /// Stops a reply that is streaming, sends a message that is written, and otherwise starts a voice conversation.
    private var primaryButton: some View {
        let viewModel = presenter.viewModel
        let symbol = viewModel.isStreaming ? "stop.fill" : (viewModel.canSend ? "arrow.up" : "waveform")
        let label = viewModel.isStreaming ? Strings.stopReply : (viewModel.canSend ? Strings.send : Strings.startVoice)
        return Button(action: primaryAction) {
            Image(systemName: symbol)
                .font(.footnote.weight(.bold))
                .foregroundStyle(HearthColor.onPine)
                .frame(width: 34, height: 34)
                .background(HearthColor.pine, in: Circle())
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func primaryAction() {
        let viewModel = presenter.viewModel
        sendCount += 1
        if viewModel.isStreaming {
            Task { await presenter.stopAction() }
        } else if viewModel.canSend {
            Task { await presenter.sendAction() }
        } else {
            isFocused = false
            presenter.voiceAction()
        }
    }
}
