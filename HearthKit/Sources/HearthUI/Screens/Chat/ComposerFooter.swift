import HearthDomain
import SwiftUI

/// Where a message is written: text, attachments, the search toggle, dictation and send.
struct ComposerFooter: View {
    let presenter: ChatPresenter

    @State private var sendCount = 0
    @FocusState private var isFocused: Bool

    var body: some View {
        @Bindable var viewModel = presenter.viewModel
        VStack(alignment: .leading, spacing: 10) {
            if viewModel.editingMessageID != nil {
                editingHeader
            }
            if !viewModel.pendingImagesJPEG.isEmpty {
                PhotoStrip(imagesJPEG: viewModel.pendingImagesJPEG, sideLength: 64, removeAction: presenter.removeImageAction(at:))
            }
            if !viewModel.pendingDocuments.isEmpty {
                DocumentStrip(documents: viewModel.pendingDocuments, removeAction: presenter.removeDocumentAction)
            }
            TextField(placeholder, text: $viewModel.draft, axis: .vertical)
                .lineLimit(1...6)
                .font(.body)
                .foregroundStyle(HearthColor.ink)
                .tint(HearthColor.pine)
                .focused($isFocused)
                .padding(.horizontal, 4)
            HStack(spacing: 8) {
                AttachmentMenu(presenter: presenter)
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
        .padding(.vertical, 8)
        .sensoryFeedback(.impact(weight: .light), trigger: sendCount)
        .animation(.snappy, value: viewModel.editingMessageID)
        .onChange(of: viewModel.editingMessageID) {
            if viewModel.editingMessageID != nil {
                isFocused = true
            }
        }
    }

    private var placeholder: String {
        presenter.viewModel.selectedModel.map { Strings.messageModel($0.displayName) } ?? Strings.composerPlaceholder
    }

    private var editingHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "pencil")
                .font(.footnote)
                .foregroundStyle(HearthColor.pine)
                .accessibilityHidden(true)
            Text(Strings.editingMessage)
                .font(.footnote.weight(.medium))
                .foregroundStyle(HearthColor.pine)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: presenter.cancelEditAction) {
                Image(systemName: "xmark")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(HearthColor.mute)
                    .frame(width: 28, height: 24)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Strings.cancelEdit)
        }
        .padding(.horizontal, 4)
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

/// The files attached to a message, each a chip with its name.
struct DocumentStrip: View {
    let documents: [AttachedDocument]
    let removeAction: ((AttachedDocument.ID) -> Void)?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(documents) { document in
                    HStack(spacing: 6) {
                        Image(systemName: "doc.text")
                            .font(.caption)
                            .foregroundStyle(HearthColor.pine)
                            .accessibilityHidden(true)
                        Text(document.name)
                            .font(.caption)
                            .foregroundStyle(HearthColor.ink)
                            .lineLimit(1)
                        if let removeAction {
                            Button(action: { removeAction(document.id) }, label: {
                                Image(systemName: "xmark")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(HearthColor.mute)
                                    .frame(width: 20, height: 20)
                            })
                            .buttonStyle(.plain)
                            .accessibilityLabel(Strings.removeFile)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(HearthColor.paper, in: Capsule())
                    .overlay { Capsule().strokeBorder(HearthColor.line, lineWidth: 1) }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(Strings.attachedFile(document.name))
                }
            }
        }
    }
}
