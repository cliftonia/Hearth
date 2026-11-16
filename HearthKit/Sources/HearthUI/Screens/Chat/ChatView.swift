import HearthDomain
import SwiftUI

/// The chat screen: the header, the conversation or its empty state, any error, and the composer.
struct ChatView: View {
    private static let followUpsID = "followUps"
    private static let messageSpacing: CGFloat = 22

    let presenter: ChatPresenter

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        let viewModel = presenter.viewModel
        VStack(spacing: 0) {
            ChatHeader(presenter: presenter)
            // Both stay in the tree with one of them hidden, rather than being swapped, so neither is rebuilt as a chat begins.
            ZStack {
                messageList(viewModel: viewModel)
                    .opacity(viewModel.conversation.messages.isEmpty ? 0 : 1)
                EmptyChatSection(
                    isServerConfigured: presenter.isServerConfigured,
                    greeting: presenter.greeting,
                    isPrivate: viewModel.conversation.isPrivate,
                    settingsAction: presenter.settingsAction
                )
                    .opacity(viewModel.conversation.messages.isEmpty ? 1 : 0)
                    .allowsHitTesting(viewModel.conversation.messages.isEmpty)
                    .accessibilityHidden(!viewModel.conversation.messages.isEmpty)
            }
            // It may shrink to nothing, so a tall keyboard squeezes this and never pushes the composer beneath itself.
            .frame(minHeight: 0, maxHeight: .infinity)
            .frame(maxWidth: .infinity)
            .clipped()
            // A tap anywhere in the conversation puts the keyboard away, without taking the tap from what was tapped.
            .contentShape(Rectangle())
            .simultaneousGesture(TapGesture().onEnded { Keyboard.dismiss() })
            if let error = viewModel.error {
                ErrorBannerSection(
                    configuration: error,
                    retryAction: { Task { await presenter.retryAction() } },
                    dismissAction: { viewModel.error = nil }
                )
                .frame(maxWidth: HearthSize.readingWidth)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            ComposerFooter(presenter: presenter)
                .frame(maxWidth: HearthSize.readingWidth)
        }
        .background(HearthColor.paper.ignoresSafeArea())
        .animation(.snappy, value: viewModel.error)
        // One haptic as a turn ends, never while its text streams: soft for a reply, fuller for a picture.
        // Nothing is played for a turn that ends off screen, or one that came to nothing.
        .onChange(of: viewModel.isStreaming) { _, isStreaming in
            let last = viewModel.conversation.messages.last
            guard !isStreaming, scenePhase == .active, viewModel.error == nil, let last, last.role == .assistant, !last.isEmpty else {
                return
            }
            Haptics.play(last.isPicture ? .success : .soft)
        }
        .haptic(.error, trigger: viewModel.error) { _, new in new != nil }
        .alert(Strings.renameChat, isPresented: Bindable(viewModel).isRenamingChat) {
            TextField(Strings.chatTitle, text: Bindable(viewModel).chatTitleDraft)
            Button(Strings.cancel, role: .cancel) {}
            Button(Strings.save) { Task { await presenter.commitRenameChatAction() } }
        }
        .sheet(isPresented: Bindable(viewModel).isModelPickerPresented) {
            ModelPickerSheet(presenter: presenter)
        }
        .task { await presenter.loadAction() }
    }

    /// The messages, the latest notice and suggestions beneath them, kept scrolled to the newest.
    private func messageList(viewModel: ChatViewModel) -> some View {
        let messages = viewModel.conversation.messages
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Self.messageSpacing) {
                    ForEach(messages) { message in
                        messageSection(message, isLast: message.id == messages.last?.id, viewModel: viewModel)
                            .id(message.id)
                    }
                    if let notice = viewModel.memoryNotice {
                        MemoryNoticeSection(notice: notice)
                    }
                    if !viewModel.followUps.isEmpty, !viewModel.isStreaming {
                        FollowUpSection(questions: viewModel.followUps) { question in
                            Task { await presenter.followUpAction(question) }
                        }
                        .id(Self.followUpsID)
                        .transition(.opacity)
                    }
                }
                .animation(.snappy, value: viewModel.followUps)
                .animation(.snappy, value: viewModel.memoryNotice)
                .padding(.horizontal, HearthSpacing.s16)
                .padding(.vertical, HearthSpacing.s12)
                .frame(maxWidth: HearthSize.readingWidth)
                .frame(maxWidth: .infinity)
            }
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: messages.count) {
                withAnimation(.snappy) {
                    proxy.scrollTo(messages.last?.id, anchor: .bottom)
                }
            }
            .onChange(of: viewModel.followUps) {
                withAnimation(.snappy) {
                    proxy.scrollTo(Self.followUpsID, anchor: .bottom)
                }
            }
        }
    }

    /// One message, with the passing state and the actions that apply to it.
    private func messageSection(_ message: Message, isLast: Bool, viewModel: ChatViewModel) -> some View {
        MessageSection(
            message: message,
            isStreaming: viewModel.isStreaming && isLast,
            isSpeaking: viewModel.speakingMessageID == message.id,
            searchingQuery: isLast ? viewModel.searchingQuery : nil,
            pictureStatus: isLast ? viewModel.pictureStatus : nil,
            researchStatus: isLast ? viewModel.researchStatus : nil,
            speakAction: presenter.isSpeechAvailable ? { Task { await presenter.speakAction(message.id) } } : nil,
            editAction: viewModel.isStreaming ? nil : { presenter.editAction(message.id) },
            retryAction: isLast ? { Task { await presenter.regenerateAction() } } : nil,
            versionAction: viewModel.isStreaming ? nil : { index in Task { await presenter.selectVersionAction(index, of: message.id) } },
            canvasAction: { index in presenter.canvasAction(CanvasReference(messageID: message.id, index: index)) }
        )
    }
}
