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
                EmptyChatSection(isServerConfigured: presenter.isServerConfigured, settingsAction: presenter.settingsAction)
                    .opacity(viewModel.conversation.messages.isEmpty ? 1 : 0)
                    .allowsHitTesting(viewModel.conversation.messages.isEmpty)
                    .accessibilityHidden(!viewModel.conversation.messages.isEmpty)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            if let error = viewModel.error {
                ErrorBannerSection(
                    configuration: error,
                    retryAction: { Task { await presenter.retryAction() } },
                    dismissAction: { viewModel.error = nil }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            ComposerFooter(presenter: presenter)
        }
        .background(HearthColor.paper.ignoresSafeArea())
        .animation(.snappy, value: viewModel.error)
        .task { await presenter.loadAction() }
    }

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
                            speakAction: presenter.isSpeechAvailable ? { Task { await presenter.speakAction(message.id) } } : nil,
                            editAction: viewModel.isStreaming ? nil : { presenter.editAction(message.id) },
                            retryAction: message.id == messages.last?.id ? { Task { await presenter.regenerateAction() } } : nil
                        )
                        .id(message.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: messages.count) {
                withAnimation(.snappy) {
                    proxy.scrollTo(messages.last?.id, anchor: .bottom)
                }
            }
        }
    }
}

private struct EmptyChatSection: View {
    let isServerConfigured: Bool
    let settingsAction: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HearthMark(sideLength: 56)
            Text(isServerConfigured ? Strings.emptyTitle : Strings.connectTitle)
                .font(HearthFont.display)
                .foregroundStyle(HearthColor.ink)
                .multilineTextAlignment(.center)
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
