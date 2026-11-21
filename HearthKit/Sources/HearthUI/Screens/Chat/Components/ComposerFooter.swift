import HearthDomain
import SwiftUI

/// Where a message is written: text, attachments, the reply's options, dictation and send.
///
/// At rest it is a single row. It opens out, showing the model and web search, while a message is being written.
/// Reading replies aloud is switched in the plus menu.
struct ComposerFooter: View {
    private static let pendingPhotoSide: CGFloat = 64
    private static let cancelEditSize = CGSize(width: 28, height: 24)
    /// Rounds the model chip into a capsule while it is one line high.
    private static let chipRadius = HearthSize.optionChip.height / 2
    /// How much larger the composer stands while a finger rests on it.
    private static let heldScale: CGFloat = 1.06
    /// The gap beneath the composer.
    #if targetEnvironment(macCatalyst)
    private static let bottomGap = HearthSpacing.macBottomEdge
    #else
    private static let bottomGap = HearthSpacing.s8
    #endif

    let presenter: ChatPresenter

    @State private var sendCount = 0
    /// Whether a finger is resting on the field at this moment, before or during a hold.
    @State private var isPressed = false
    @FocusState private var isFocused: Bool
    @AccessibilityFocusState private var isVoiceOverFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
            // The recording row lies over the composer's own row, which stays in place so the field keeps its identity.
            ZStack {
                ComposerLayout(isCompact: !isExpanded, spacing: isExpanded ? HearthSpacing.s10 : HearthSpacing.s6) {
                    // The words in the empty field are drawn in the secondary colour rather than the system's fainter
                    // one, so that they read on the see-through composer whatever scrolls beneath it.
                    TextField(placeholder, text: $viewModel.draft, prompt: Text(placeholder).foregroundStyle(HearthColor.mute), axis: .vertical)
                        .lineLimit(1...6)
                        .font(.hearth(.body))
                        .foregroundStyle(HearthColor.ink)
                        .tint(HearthColor.pine)
                        .focused($isFocused)
                        .accessibilityFocused($isVoiceOverFocused)
                        .padding(.horizontal, HearthSpacing.s4)
                        // A hardware keyboard's Return sends, and Shift-Return starts a new line. The on-screen
                        // keyboard sends no key presses, so on it Return still starts a new line.
                        .onKeyPress(.return, phases: .down) { press in
                            returnKeyAction(modifiers: press.modifiers)
                        }
                        .concealed(isHeld)
                        .overlay { holdToTalkTouchLayer }
                    leadingControls
                        .concealed(isHeld)
                    HStack(spacing: HearthSpacing.s8) {
                        dictationButton
                        primaryButton
                    }
                    .concealed(isHeld)
                }
                HoldToTalkRow(level: viewModel.voiceLevel, stopAction: presenter.holdToTalkEndedAction)
                    .concealed(!isHeld)
            }
        }
        .padding(.horizontal, HearthSpacing.s12)
        .padding(.top, isExpanded ? HearthSpacing.s12 : HearthSpacing.s10)
        .padding(.bottom, HearthSpacing.s10)
        // See-through, so the conversation that scrolls on beneath the composer shows faintly through it.
        .frostedSurface(RoundedRectangle(cornerRadius: HearthRadius.composer, style: .continuous))
        .hearthShadow(.composer)
        // The moment a finger rests on it the composer grows a little, and stays so for as long as it is held,
        // unless motion is reduced.
        .scaleEffect((isPressed || isHeld) && !reduceMotion ? Self.heldScale : 1)
        .padding(.horizontal, HearthSpacing.s12)
        .padding(.top, HearthSpacing.s8)
        .padding(.bottom, Self.bottomGap)
        .haptic(.light, trigger: sendCount)
        .haptic(.light, trigger: viewModel.isPictureMode)
        .haptic(.light, trigger: isRecordingHeld, when: { _, isRecording in isRecording })
        .haptic(.soft, trigger: isRecordingHeld, when: { wasRecording, _ in wasRecording })
        .animation(composerAnimation, value: isHeld)
        .animation(reduceMotion ? nil : .spring(response: 0.16, dampingFraction: 0.65), value: isPressed || isHeld)
        .animation(composerAnimation, value: viewModel.editingMessageID)
        .animation(composerAnimation, value: isExpanded)
        // A different conversation starts with the composer at rest.
        .onChange(of: viewModel.conversation.id) {
            isFocused = false
        }
        .onChange(of: viewModel.editingMessageID) {
            if viewModel.editingMessageID != nil {
                isFocused = true
            }
        }
        // Words dictated by holding are there to be read and sent, so the composer opens out with the keyboard.
        .onChange(of: viewModel.dictatedDraftCount) {
            isFocused = true
        }
        // The chat handed back, as when the canvas closes: VoiceOver returns here, and no keyboard is raised.
        .onChange(of: viewModel.focusRequestCount) {
            isVoiceOverFocused = true
        }
    }

    // MARK: Arrangement

    /// How the composer changes shape: a quick spring, or a plain fade when motion is reduced.
    private var composerAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .snappy
    }

    /// Whether the composer has opened out: it holds the keyboard, or something has been typed.
    private var isExpanded: Bool {
        isFocused || !presenter.viewModel.draft.isEmpty
    }

    /// The model the message goes to and the effort chosen for it, or the picture model while pictures are being made.
    /// Tapping it opens the sheet where both are chosen.
    var modelChip: some View {
        let viewModel = presenter.viewModel
        let name = viewModel.isPictureMode
            ? presenter.selectedPictureModel?.name ?? Strings.pictures
            : viewModel.selectedModel?.displayName ?? Strings.noModel
        let effort = viewModel.isPictureMode ? "" : presenter.effortChipTitle
        // At the accessibility sizes the chip has a row to itself, and the name and the effort a line each.
        let isLarge = dynamicTypeSize.isAccessibilitySize
        let layout = isLarge ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0)) : AnyLayout(HStackLayout(spacing: HearthSpacing.s6))
        return Button(action: { viewModel.isModelPickerPresented = true }, label: {
            layout {
                Text(name)
                    .font(.hearth(.footnote).weight(.medium))
                    .foregroundStyle(HearthColor.ink)
                    .lineLimit(1)
                    .truncationMode(.middle)
                // Research stands out in the brand colour, so it is plain that the next message will be researched.
                Text(effort)
                    .font(.hearth(.footnote))
                    .foregroundStyle(presenter.isResearchChosen ? HearthColor.pine : HearthColor.mute)
                    .lineLimit(1)
                    // Research is never shortened; where room is tight the model's name gives way to it.
                    .fixedSize(horizontal: presenter.isResearchChosen && !isLarge, vertical: false)
                    .layoutPriority(1)
                    .frame(width: effort.isEmpty && !isLarge ? 0 : nil)
                    .folded(effort.isEmpty && isLarge)
            }
            .padding(.horizontal, HearthSpacing.s12)
            .padding(.vertical, isLarge ? HearthSpacing.s6 : 0)
            .frame(minHeight: HearthSize.optionChip.height)
            .background(HearthColor.bubble, in: RoundedRectangle(cornerRadius: isLarge ? HearthRadius.card : Self.chipRadius, style: .continuous))
            .minimumHitTarget()
            .hoverHighlight(RoundedRectangle(cornerRadius: isLarge ? HearthRadius.card : Self.chipRadius, style: .continuous))
        })
        .buttonStyle(.plain)
        .accessibilityLabel(viewModel.isPictureMode ? Strings.pictureModelPickerLabel : Strings.modelPickerLabel)
        .accessibilityValue(effort.isEmpty ? name : Strings.modelAndEffort(model: name, effort: effort))
    }

    /// Shows that the next message asks for a picture; tapping it goes back to chatting.
    var pictureModeChip: some View {
        Button(action: presenter.togglePictureModeAction) {
            OptionChip(systemImage: "paintbrush.fill", isOn: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Strings.pictureMode)
        .accessibilityAddTraits(.isSelected)
        .largeContentLabel(Strings.pictureMode, systemImage: "paintbrush.fill")
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
        // Research says so in the field too, where it shows even while the composer is at rest.
        if presenter.isResearchChosen {
            return Strings.researchPlaceholder
        }
        // At rest the composer says what can be done with it; once opened it says who is being written to, beside the
        // chip that changes it.
        if !isExpanded {
            // Once the chat is under way, what is written next is a reply.
            return presenter.viewModel.conversation.messages.isEmpty ? Strings.composerRestingPlaceholder : Strings.composerReplyPlaceholder
        }
        return presenter.viewModel.selectedModel.map { Strings.messageModel($0.displayName) } ?? Strings.composerPlaceholder
    }

    // MARK: Editing

    /// Says that a sent message is being edited, and offers to leave it as it was.
    private var editingHeader: some View {
        HStack(spacing: HearthSpacing.s8) {
            Image(systemName: "pencil")
                .font(.hearth(.footnote))
                .foregroundStyle(HearthColor.pine)
                .accessibilityHidden(true)
            Text(Strings.editingMessage)
                .font(.hearth(.footnote).weight(.medium))
                .foregroundStyle(HearthColor.pine)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: presenter.cancelEditAction) {
                Image(systemName: "xmark")
                    .font(.hearth(.footnote).weight(.semibold))
                    .iconGlyphSize()
                    .foregroundStyle(HearthColor.mute)
                    .frame(size: Self.cancelEditSize)
                    .minimumHitTarget()
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Strings.cancelEdit)
            .largeContentLabel(Strings.cancelEdit, systemImage: "xmark")
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
        .largeContentLabel(Strings.searchLabel, systemImage: "globe")
    }
}

// MARK: Dictation and send

private extension ComposerFooter {
    /// Whether the composer is being held down to talk, so the recording row shows in place of its own.
    var isHeld: Bool {
        presenter.viewModel.holdToTalk.isActive
    }

    /// Whether the held composer is listening yet. Leave may still be being asked while it is merely held.
    var isRecordingHeld: Bool {
        presenter.viewModel.holdToTalk.phase == .recording
    }

    /// Lies over the resting field: a tap gives the field the keyboard as before, and a hold starts recording.
    /// Once the composer has opened out, touches go straight to the field.
    var holdToTalkTouchLayer: some View {
        HoldToTalkTouchLayer(
            tapAction: { isFocused = true },
            pressChangedAction: { isPressed = $0 },
            holdBeganAction: presenter.holdToTalkBeganAction,
            holdEndedAction: presenter.holdToTalkEndedAction
        )
        .allowsHitTesting(!isExpanded)
    }

    /// Dictates into the field; it turns to the danger colour while the microphone is live.
    var dictationButton: some View {
        let isDictating = presenter.viewModel.isDictating
        return Button(action: { Task { await presenter.dictationAction() } }, label: {
            Image(systemName: isDictating ? "mic.fill" : "mic")
                .font(.hearth(.footnote).weight(.medium))
                .iconGlyphSize()
                .foregroundStyle(isDictating ? HearthColor.danger : HearthColor.ink)
                .frame(size: HearthSize.composerControl)
                .glassControlSurface(isDictating ? HearthColor.danger : nil)
                .minimumHitTarget()
                .hoverHighlight(Capsule())
        })
        .buttonStyle(.plain)
        .accessibilityLabel(isDictating ? Strings.stopDictation : Strings.dictate)
        .largeContentLabel(isDictating ? Strings.stopDictation : Strings.dictate, systemImage: "mic")
    }

    /// Stops a reply that is streaming, sends a message that is written, and otherwise starts a voice conversation.
    var primaryButton: some View {
        let (symbol, label) = switch presenter.primaryKind {
        case .stop:
            ("stop.fill", Strings.stopReply)
        case .send:
            ("arrow.up", Strings.send)
        case .voice:
            ("waveform", Strings.startVoice)
        }
        return Button(action: primaryAction) {
            Image(systemName: symbol)
                .font(.hearth(.footnote).weight(.bold))
                .iconGlyphSize()
                .foregroundStyle(HearthColor.onPine)
                .frame(width: HearthSize.sendButton, height: HearthSize.sendButton)
                .background(HearthColor.pine, in: Circle())
                .contentTransition(.symbolEffect(.replace))
                .minimumHitTarget()
                .hoverHighlight(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .largeContentLabel(label, systemImage: symbol)
    }

    func primaryAction() {
        sendCount += 1
        // Sending puts the keyboard away, leaving the whole screen for the reply; so does starting to talk.
        if presenter.primaryKind != .stop {
            isFocused = false
        }
        Task { await presenter.primaryAction() }
    }

    /// Return from a hardware keyboard: sends what is written, keeping the keyboard, unless Shift is held, when the
    /// field starts a new line as usual. A reply on its way is not stopped by it.
    func returnKeyAction(modifiers: EventModifiers) -> KeyPress.Result {
        switch ComposerReturnKey.outcome(modifiers: modifiers, canSend: presenter.viewModel.canSend, isStreaming: presenter.viewModel.isStreaming) {
        case .newLine:
            return .ignored
        case .send:
            sendCount += 1
            Task { await presenter.primaryAction() }
            return .handled
        case .nothing:
            return .handled
        }
    }

    // MARK: Arrangement at large sizes

    /// The plus menu, and while writing the model and web search: beside the field at rest and beneath it while
    /// writing. At the accessibility text sizes the model chip takes a row of its own above the rest, so that it is
    /// not squeezed to nothing.
    var leadingControls: some View {
        let viewModel = presenter.viewModel
        let isChipOnOwnRow = dynamicTypeSize.isAccessibilitySize && isExpanded
        return VStack(alignment: .leading, spacing: HearthSpacing.s8) {
            if isChipOnOwnRow {
                modelChip
            }
            HStack(spacing: HearthSpacing.s8) {
                AttachmentMenu(presenter: presenter)
                if viewModel.isPictureMode {
                    pictureModeChip
                    PicturePhotoButton(presenter: presenter)
                }
                if isExpanded, !isChipOnOwnRow {
                    modelChip
                }
                if isExpanded, presenter.isSearchToggleVisible, !viewModel.isPictureMode {
                    searchToggle
                }
            }
        }
    }
}
