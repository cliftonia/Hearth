import HearthDomain
import SwiftUI

/// The chat screen: the conversation or its empty state, with the header floating over its head and the composer,
/// under any error, floating over its foot, so that the conversation scrolls on beneath both.
struct ChatView: View {
    private static let followUpsID = "followUps"
    /// The very end of the conversation, beneath whatever it ends with.
    private static let endID = "end"
    private static let messageSpacing: CGFloat = 22
    /// Whether a new chat's composer rests in the middle of the window under the greeting, as on a Mac, whose window
    /// is too tall to leave it alone at the foot.
    #if targetEnvironment(macCatalyst)
    private static let centersNewChat = true
    #else
    private static let centersNewChat = false
    #endif

    let presenter: ChatPresenter

    @Environment(\.scenePhase) private var scenePhase
    /// How much of the conversation's foot the composer and the keyboard cover, as it last was.
    @State private var footInset: CGFloat = 0

    var body: some View {
        let viewModel = presenter.viewModel
        // With nothing said yet, a Mac's composer rises to the middle, the greeting resting on it.
        let isCentred = Self.centersNewChat && viewModel.conversation.messages.isEmpty && presenter.isServerConfigured
        VStack(spacing: 0) {
            // Both stay in the tree with one of them hidden, rather than being swapped, so neither is rebuilt as a chat begins.
            ZStack(alignment: isCentred ? .bottom : .center) {
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
            // A tap anywhere in the conversation puts the keyboard away, without taking the tap from what was tapped.
            .contentShape(Rectangle())
            .simultaneousGesture(TapGesture().onEnded { Keyboard.dismiss() })
            .modifier(ChatBarsPlacement(presenter: presenter, isCentred: isCentred))
        }
        .background(HearthColor.paper.ignoresSafeArea())
        .animation(.snappy, value: viewModel.error)
        .animation(.snappy, value: isCentred)
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
        .confirmationDialog(Strings.deleteChatQuestion, isPresented: Bindable(viewModel).isConfirmingDeleteChat, titleVisibility: .visible) {
            Button(Strings.deleteChat, role: .destructive) {
                Haptics.play(.warning)
                Task { await presenter.deleteChatAction() }
            }
            Button(Strings.cancel, role: .cancel) {}
        } message: {
            Text(presenter.deleteChatDetail)
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
                VStack(spacing: 0) {
                    messageStack(messages, viewModel: viewModel)
                    // Nothing to see: a place to scroll to that is always the end.
                    Color.clear
                        .frame(height: 0)
                        .id(Self.endID)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, HearthSpacing.s16)
                .padding(.vertical, HearthSpacing.s12)
                .frame(maxWidth: HearthSize.readingWidth)
                .frame(maxWidth: .infinity)
            }
            .defaultScrollAnchor(.bottom)
            .softScrollFoot()
            .scrollDismissesKeyboard(.interactively)
            // A chat opens at its latest reply. The composer floats over the foot of the conversation and is measured
            // only once it is laid out, so the place is found again then, rather than left where the first pass put it.
            .onChange(of: viewModel.conversation.id, initial: true) {
                Task { @MainActor in
                    proxy.scrollTo(Self.endID, anchor: .bottom)
                }
            }
            // When the keyboard rises, or the composer grows a line, the end of the conversation rises with it
            // rather than being left beneath them.
            .onGeometryChange(for: CGFloat.self, of: \.safeAreaInsets.bottom) { inset in
                let hasGrown = inset > footInset
                footInset = inset
                if hasGrown {
                    withAnimation(.snappy) {
                        proxy.scrollTo(Self.endID, anchor: .bottom)
                    }
                }
            }
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

    /// The messages one under another, then the latest notice and the suggested questions.
    private func messageStack(_ messages: [Message], viewModel: ChatViewModel) -> some View {
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
            canvasAction: { index in presenter.canvasAction(CanvasReference(messageID: message.id, index: index)) },
            savePictureAction: { await presenter.savePictureAction($0) }
        )
    }
}

/// What stands at the foot of the chat: any error, and under it the composer.
private struct ChatFooter: View {
    let presenter: ChatPresenter

    var body: some View {
        let viewModel = presenter.viewModel
        VStack(spacing: 0) {
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
        .frame(maxWidth: .infinity)
    }
}

/// Where the chat's bars go: the header floating over the head of the conversation and the composer over its foot,
/// with the conversation scrolling on beneath both.
private struct ChatBarsPlacement: ViewModifier {
    let presenter: ChatPresenter
    /// Whether the composer rests in the middle of the window, as a new chat's does on a Mac.
    let isCentred: Bool

    @State private var height: CGFloat = 0
    @State private var footerHeight: CGFloat = 0

    func body(content: Content) -> some View {
        content
            // Kept to its own width, so nothing spills over a list beside it, but open at the head and the foot, so
            // the conversation can scroll on beneath the header, the composer and the edges of the screen.
            .mask {
                Rectangle()
                    .padding(.vertical, -HearthSize.scrollUnderReach)
            }
            .onGeometryChange(for: CGFloat.self, of: \.size.height) { height = $0 }
            .floatingBottomBar {
                ChatFooter(presenter: presenter)
                    .onGeometryChange(for: CGFloat.self, of: \.size.height) { footerHeight = $0 }
                    // In the middle, the composer has as much room beneath it as above it.
                    .padding(.bottom, isCentred ? max(0, (height - footerHeight) / 2) : 0)
            }
            .floatingTopBar { ChatHeader(presenter: presenter) }
    }
}
