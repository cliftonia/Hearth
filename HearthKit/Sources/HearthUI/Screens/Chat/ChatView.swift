import HearthDomain
import SwiftUI

struct ChatView: View {
    let presenter: ChatPresenter

    var body: some View {
        let viewModel = presenter.viewModel
        VStack(spacing: 0) {
            ChatHeader(presenter: presenter)
            ZStack {
                messageList(viewModel: viewModel)
                    .opacity(viewModel.conversation.messages.isEmpty ? 0 : 1)
                EmptyChatSection(
                    isServerConfigured: presenter.isServerConfigured,
                    isPrivate: viewModel.conversation.isPrivate,
                    settingsAction: presenter.settingsAction,
                    privateAction: presenter.togglePrivateAction
                )
                    .opacity(viewModel.conversation.messages.isEmpty ? 1 : 0)
                    .allowsHitTesting(viewModel.conversation.messages.isEmpty)
                    .accessibilityHidden(!viewModel.conversation.messages.isEmpty)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // A tap anywhere in the conversation puts the keyboard away, without taking the tap from what was tapped.
            .contentShape(Rectangle())
            .simultaneousGesture(TapGesture().onEnded { Keyboard.dismiss() })
            if let error = viewModel.error {
                ErrorBannerSection(
                    configuration: error,
                    retryAction: { Task { await presenter.retryAction() } },
                    dismissAction: { viewModel.error = nil }
                )
                .frame(maxWidth: Self.readingWidth)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            ComposerFooter(presenter: presenter)
                .frame(maxWidth: Self.readingWidth)
        }
        .background(HearthColor.paper.ignoresSafeArea())
        .animation(.snappy, value: viewModel.error)
        .task { await presenter.loadAction() }
    }

    /// The widest a line of chat grows, so that it stays readable on a large screen.
    private static let readingWidth: CGFloat = 780
    private static let followUpsID = "followUps"

    private func messageList(viewModel: ChatViewModel) -> some View {
        let messages = viewModel.conversation.messages
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    ForEach(messages) { message in
                        MessageSection(
                            message: message,
                            isStreaming: viewModel.isStreaming && message.id == messages.last?.id,
                            isSpeaking: viewModel.speakingMessageID == message.id,
                            searchingQuery: message.id == messages.last?.id ? viewModel.searchingQuery : nil,
                            speakAction: presenter.isSpeechAvailable ? { Task { await presenter.speakAction(message.id) } } : nil,
                            editAction: viewModel.isStreaming ? nil : { presenter.editAction(message.id) },
                            retryAction: message.id == messages.last?.id ? { Task { await presenter.regenerateAction() } } : nil
                        )
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
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: Self.readingWidth)
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
}

/// Says what was just remembered, changed or forgotten.
private struct MemoryNoticeSection: View {
    let notice: String

    var body: some View {
        Label(notice, systemImage: "bookmark.fill")
            .font(.footnote)
            .foregroundStyle(HearthColor.pine)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(HearthColor.pineSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .transition(.opacity)
    }
}

/// Questions the user might ask next; tapping one sends it.
private struct FollowUpSection: View {
    let questions: [String]
    let action: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(questions, id: \.self) { question in
                Rectangle().fill(HearthColor.line).frame(height: 1)
                Button(action: { action(question) }, label: {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(question)
                            .font(.subheadline)
                            .foregroundStyle(HearthColor.ink)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "arrow.turn.down.right")
                            .font(.footnote)
                            .foregroundStyle(HearthColor.pine)
                            .accessibilityHidden(true)
                    }
                    .padding(.vertical, 11)
                    .contentShape(Rectangle())
                })
                .buttonStyle(.plain)
                .accessibilityHint(Strings.followUpHint)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Strings.followUps)
    }
}

private struct EmptyChatSection: View {
    let isServerConfigured: Bool
    let isPrivate: Bool
    let settingsAction: () -> Void
    let privateAction: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HearthMark(sideLength: 56)
            Text(isServerConfigured ? Strings.emptyTitle : Strings.connectTitle)
                .font(HearthFont.display)
                .foregroundStyle(HearthColor.ink)
                .multilineTextAlignment(.center)
            if isServerConfigured {
                Button(action: privateAction) {
                    Label(Strings.privateChat, systemImage: isPrivate ? "eye.slash.fill" : "eye.slash")
                        .font(.footnote.weight(isPrivate ? .semibold : .regular))
                        .foregroundStyle(isPrivate ? HearthColor.pine : HearthColor.mute)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(isPrivate ? HearthColor.pineSoft : .clear, in: Capsule())
                        .overlay { Capsule().strokeBorder(isPrivate ? .clear : HearthColor.line, lineWidth: 1) }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isPrivate ? .isSelected : [])
                Text(Strings.privateChatNote)
                    .font(.footnote)
                    .foregroundStyle(HearthColor.mute)
                    .multilineTextAlignment(.center)
                    .opacity(isPrivate ? 1 : 0)
                    .accessibilityHidden(!isPrivate)
            }
            if !isServerConfigured {
                Text(Strings.connectMessage)
                    .font(.subheadline)
                    .foregroundStyle(HearthColor.mute)
                    .multilineTextAlignment(.center)
                Button(Strings.openSettings, action: settingsAction)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(HearthColor.onPine)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(HearthColor.pine, in: Capsule())
                    .buttonStyle(.plain)
            }
        }
        .padding(32)
    }
}

private struct ErrorBannerSection: View {
    let configuration: ErrorViewConfiguration
    let retryAction: () -> Void
    let dismissAction: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(configuration.title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(HearthColor.ink)
                Text(configuration.message)
                    .font(.footnote)
                    .foregroundStyle(HearthColor.mute)
                    .lineLimit(4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let retryActionLabel = configuration.retryActionLabel {
                Button(retryActionLabel, action: retryAction)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(HearthColor.pine)
                    .buttonStyle(.plain)
            }
            Button(action: dismissAction) {
                Image(systemName: "xmark")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(HearthColor.mute)
                    .frame(width: 24, height: 20)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Strings.dismiss)
        }
        .padding(12)
        .background(HearthColor.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(HearthColor.danger.opacity(0.5), lineWidth: 1)
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
    }
}
