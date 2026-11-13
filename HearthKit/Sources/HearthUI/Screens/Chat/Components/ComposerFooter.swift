import HearthDomain
import SwiftUI

/// Where a message is written: text, attachments, the reply's options, dictation and send.
///
/// At rest it is a single row. It opens out, showing its options, while a message is being written.
struct ComposerFooter: View {
    private static let pendingPhotoSide: CGFloat = 64
    private static let cancelEditSize = CGSize(width: 28, height: 24)

    let presenter: ChatPresenter

    @State private var sendCount = 0
    @FocusState private var isFocused: Bool

    var body: some View {
        @Bindable var viewModel = presenter.viewModel
        VStack(alignment: .leading, spacing: HearthSpacing.s10) {
            if viewModel.editingMessageID != nil {
                editingHeader
            }
            if !viewModel.pendingImagesJPEG.isEmpty {
                PhotoStrip(imagesJPEG: viewModel.pendingImagesJPEG, sideLength: Self.pendingPhotoSide, removeAction: presenter.removeImageAction(at:))
            }
            if !viewModel.pendingDocuments.isEmpty {
                DocumentStrip(documents: viewModel.pendingDocuments, removeAction: presenter.removeDocumentAction)
            }
            ComposerLayout(isCompact: !isExpanded, spacing: isExpanded ? HearthSpacing.s10 : HearthSpacing.s6) {
                TextField(placeholder, text: $viewModel.draft, axis: .vertical)
                    .lineLimit(1...6)
                    .font(.body)
                    .foregroundStyle(HearthColor.ink)
                    .tint(HearthColor.pine)
                    .focused($isFocused)
                    .padding(.horizontal, HearthSpacing.s4)
                HStack(spacing: HearthSpacing.s8) {
                    AttachmentMenu(presenter: presenter)
                    if viewModel.isPictureMode {
                        pictureModeChip
                    }
                    if isExpanded, !viewModel.isPictureMode {
                        optionChips
                    }
                }
                HStack(spacing: HearthSpacing.s8) {
                    dictationButton
                    primaryButton
                }
            }
        }
        .padding(.horizontal, HearthSpacing.s12)
        .padding(.top, isExpanded ? HearthSpacing.s12 : HearthSpacing.s10)
        .padding(.bottom, HearthSpacing.s10)
        .cardSurface(radius: HearthRadius.composer)
        .hearthShadow(.composer)
        .padding(.horizontal, HearthSpacing.s12)
        .padding(.vertical, HearthSpacing.s8)
        .sensoryFeedback(.impact(weight: .light), trigger: sendCount)
        .animation(.snappy, value: viewModel.editingMessageID)
        .animation(.snappy, value: isExpanded)
        // A different conversation starts with the composer at rest.
        .onChange(of: viewModel.conversation.id) {
            isFocused = false
        }
        .onChange(of: viewModel.editingMessageID) {
            if viewModel.editingMessageID != nil {
                isFocused = true
            }
        }
    }

    // MARK: Arrangement

    /// Whether the composer has opened out: it holds the keyboard, or something has been typed.
    private var isExpanded: Bool {
        isFocused || !presenter.viewModel.draft.isEmpty
    }

    /// The switches that shape a reply: web search, how hard to think, and reading aloud.
    @ViewBuilder private var optionChips: some View {
        if presenter.isSearchToggleVisible {
            searchToggle
        }
        if presenter.viewModel.selectedModel?.canThink == true {
            thinkingMenu
        }
        if presenter.isSpeechAvailable {
            readAloudToggle
        }
    }

    /// Shows that the next message asks for a picture; tapping it goes back to chatting.
    private var pictureModeChip: some View {
        Button(action: presenter.togglePictureModeAction) {
            OptionChip(systemImage: "paintbrush.fill", isOn: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Strings.pictureMode)
        .accessibilityAddTraits(.isSelected)
    }

    private var placeholder: String {
        if presenter.viewModel.isPictureMode {
            if !presenter.viewModel.pendingImagesJPEG.isEmpty {
                return Strings.pictureChangePlaceholder
            }
            // With a picture already made, what is written is taken to be about it.
            let hasPicture = presenter.viewModel.conversation.messages.contains(where: \.isPicture)
            return hasPicture ? Strings.pictureFollowUpPlaceholder : Strings.picturePlaceholder
        }
        return presenter.viewModel.selectedModel.map { Strings.messageModel($0.displayName) } ?? Strings.composerPlaceholder
    }

    // MARK: Editing

    /// Says that a sent message is being edited, and offers to leave it as it was.
    private var editingHeader: some View {
        HStack(spacing: HearthSpacing.s8) {
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
                    .frame(size: Self.cancelEditSize)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Strings.cancelEdit)
        }
        .padding(.horizontal, HearthSpacing.s4)
    }

    // MARK: Options

    /// Searches the web before replying, for a model that cannot ask for a search itself.
    private var searchToggle: some View {
        let isOn = presenter.viewModel.isSearchEnabled
        return Button(action: presenter.toggleSearchAction) {
            OptionChip(systemImage: "globe", isOn: isOn)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Strings.searchLabel)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    /// How hard the model should think: off, light, medium or high.
    private var thinkingMenu: some View {
        let level = presenter.thinkingLevel
        return Menu {
            Picker(Strings.thinkingLevel, selection: thinkingSelection) {
                ForEach(ThinkingLevelKind.allCases, id: \.self) { option in
                    Text(option.title).tag(option)
                }
            }
        } label: {
            OptionChip(systemImage: level == .off ? "lightbulb.slash" : "lightbulb", isOn: level != .off)
        }
        .accessibilityLabel(Strings.thinkingLevel)
        .accessibilityValue(level.title)
    }

    /// The menu's picker reads the level from the settings and writes a choice back through the presenter.
    private var thinkingSelection: Binding<ThinkingLevelKind> {
        Binding(get: { presenter.thinkingLevel }, set: { presenter.selectThinkingLevelAction($0) })
    }

    /// When on, every reply is read aloud as soon as it is finished.
    private var readAloudToggle: some View {
        let isOn = presenter.isAutoReadEnabled
        return Button(action: { Task { await presenter.toggleAutoReadAction() } }, label: {
            OptionChip(systemImage: isOn ? "speaker.wave.2.fill" : "speaker.wave.2", isOn: isOn)
        })
        .buttonStyle(.plain)
        .accessibilityLabel(Strings.readRepliesAloud)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    // MARK: Dictation and send

    /// Dictates into the field; it turns to the danger colour while the microphone is live.
    private var dictationButton: some View {
        let isDictating = presenter.viewModel.isDictating
        return Button(action: { Task { await presenter.dictationAction() } }, label: {
            Image(systemName: isDictating ? "mic.fill" : "mic")
                .font(.footnote.weight(.medium))
                .foregroundStyle(isDictating ? HearthColor.danger : HearthColor.mute)
                .frame(size: HearthSize.composerControl)
                .capsuleOutline(isDictating ? HearthColor.danger : HearthColor.line)
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
                .frame(width: HearthSize.sendButton, height: HearthSize.sendButton)
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
            // Sending puts the keyboard away, leaving the whole screen for the reply.
            isFocused = false
            Task { await presenter.sendAction() }
        } else {
            isFocused = false
            presenter.voiceAction()
        }
    }
}
