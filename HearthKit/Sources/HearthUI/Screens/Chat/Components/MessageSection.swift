import HearthDomain
import SwiftUI
import UIKit

/// One message in the chat: the user's in a bubble, the assistant's as open text with its extras.
struct MessageSection: View {
    private static let bubbleRadii = RectangleCornerRadii(
        topLeading: HearthRadius.bubble,
        bottomLeading: HearthRadius.bubble,
        bottomTrailing: HearthRadius.bubbleTail,
        topTrailing: HearthRadius.bubble
    )
    /// Keeps a long message of the user's from reaching the leading edge, so it still reads as theirs.
    private static let bubbleLeadingInset: CGFloat = 48

    let message: Message
    let isStreaming: Bool
    let isSpeaking: Bool
    /// What the web is being searched for while this reply is on its way.
    let searchingQuery: String?
    /// Each action is `nil` when it does not apply to this message, and its button is then left out.
    let speakAction: (() -> Void)?
    let editAction: (() -> Void)?
    let retryAction: (() -> Void)?
    /// Shows the version of the reply at the given place, for a reply that was asked for more than once.
    let versionAction: ((Int) -> Void)?

    @State private var copyCount = 0

    var body: some View {
        switch message.role {
        case .user:
            userBubble
        case .assistant:
            assistantReply
        }
    }

    // MARK: The user's message

    private var userBubble: some View {
        VStack(alignment: .trailing, spacing: HearthSpacing.s6) {
            if !message.imagesJPEG.isEmpty {
                PhotoStrip(imagesJPEG: message.imagesJPEG, sideLength: 96, removeAction: nil)
            }
            if !message.documents.isEmpty {
                DocumentStrip(documents: message.documents, removeAction: nil)
            }
            if !message.text.isEmpty {
                Text(message.text)
                    .font(.body)
                    .foregroundStyle(HearthColor.ink)
                    .padding(.horizontal, HearthSpacing.s14)
                    .padding(.vertical, HearthSpacing.s10)
                    .background(HearthColor.bubble, in: UnevenRoundedRectangle(cornerRadii: Self.bubbleRadii, style: .continuous))
                    .contentShape(.contextMenuPreview, UnevenRoundedRectangle(cornerRadii: Self.bubbleRadii, style: .continuous))
                    .contextMenu { userMenu }
            }
        }
        .padding(.leading, Self.bubbleLeadingInset)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    // MARK: The assistant's reply

    private var assistantReply: some View {
        VStack(alignment: .leading, spacing: HearthSpacing.s12) {
            if !message.thinking.isEmpty {
                ThinkingSection(thinking: message.thinking, seconds: message.thinkingSeconds, isActive: isStreaming && message.text.isEmpty)
            }
            if message.text.isEmpty, message.thinking.isEmpty, isStreaming, searchingQuery == nil {
                WritingIndicator()
            }
            if let searchingQuery, isStreaming {
                Label(Strings.searching(for: searchingQuery), systemImage: "globe")
                    .font(.footnote)
                    .foregroundStyle(HearthColor.mute)
                    .lineLimit(2)
            }
            if !message.text.isEmpty {
                MarkdownSection(markdown: message.text)
                    .textSelection(.enabled)
            }
            if !message.sources.isEmpty {
                SourcesSection(sources: message.sources)
            }
            // The actions keep their place while a reply streams, so the text above does not jump when it ends.
            actions
                .opacity(isStreaming || message.text.isEmpty ? 0 : 1)
                .accessibilityHidden(isStreaming || message.text.isEmpty)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// What a long press on the user's bubble offers.
    @ViewBuilder private var userMenu: some View {
        Button(action: copyAction) {
            Label(Strings.copy, systemImage: "doc.on.doc")
        }
        if let editAction {
            Button(action: editAction) {
                Label(Strings.edit, systemImage: "pencil")
            }
        }
    }

    private func copyAction() {
        UIPasteboard.general.string = message.text
        copyCount += 1
    }

    /// The row of buttons under a finished reply.
    private var actions: some View {
        HStack(spacing: HearthSpacing.s4) {
            actionButton(systemImage: "doc.on.doc", label: Strings.copy, action: copyAction)
            ShareLink(item: message.text) {
                Image(systemName: "square.and.arrow.up")
                    .font(.footnote)
                    .foregroundStyle(HearthColor.mute)
                    .frame(size: HearthSize.messageAction)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(Strings.share)
            if let speakAction {
                actionButton(
                    systemImage: isSpeaking ? "stop.circle" : "speaker.wave.2",
                    label: isSpeaking ? Strings.stopReading : Strings.readAloud,
                    action: speakAction
                )
            }
            if let retryAction {
                actionButton(systemImage: "arrow.counterclockwise", label: Strings.tryAgain, action: retryAction)
            }
            if let versionAction, message.versionCount > 1 {
                versionStepper(versionAction)
            }
        }
        .sensoryFeedback(.success, trigger: copyCount)
    }

    /// Steps back and forth through the versions of a reply, with the place of the one shown between the arrows.
    private func versionStepper(_ action: @escaping (Int) -> Void) -> some View {
        let index = message.versionIndex
        return HStack(spacing: 0) {
            actionButton(systemImage: "chevron.left", label: Strings.previousVersion) { action(index - 1) }
                .disabled(index == 0)
                .opacity(index == 0 ? 0.35 : 1)
            Text(verbatim: "\(index + 1)/\(message.versionCount)")
                .font(.footnote.monospacedDigit())
                .foregroundStyle(HearthColor.mute)
                .accessibilityLabel(Strings.versionPosition(number: index + 1, total: message.versionCount))
            actionButton(systemImage: "chevron.right", label: Strings.nextVersion) { action(index + 1) }
                .disabled(index == message.versionCount - 1)
                .opacity(index == message.versionCount - 1 ? 0.35 : 1)
        }
    }

    private func actionButton(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.footnote)
                .foregroundStyle(HearthColor.mute)
                .frame(size: HearthSize.messageAction)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// The model's reasoning, folded away until asked for.
private struct ThinkingSection: View {
    private static let dotDiameter: CGFloat = 7
    private static let dotSpacing: CGFloat = 7
    private static let quoteBarWidth: CGFloat = 2

    let thinking: String
    let seconds: Int?
    let isActive: Bool

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: HearthSpacing.s8) {
            Button(action: { isExpanded.toggle() }, label: {
                HStack(spacing: Self.dotSpacing) {
                    Circle()
                        .fill(HearthColor.pine)
                        .frame(width: Self.dotDiameter, height: Self.dotDiameter)
                        .opacity(isActive ? 0.35 : 1)
                        .animation(isActive ? .easeInOut(duration: 0.7).repeatForever(autoreverses: true) : .default, value: isActive)
                    Text(title)
                        .font(.footnote)
                        .foregroundStyle(HearthColor.mute)
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(HearthColor.mute)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            })
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityAddTraits(isExpanded ? .isSelected : [])
            if isExpanded {
                Text(thinking.trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(.footnote)
                    .foregroundStyle(HearthColor.mute)
                    .padding(.leading, HearthSpacing.s12)
                    .overlay(alignment: .leading) {
                        Rectangle().fill(HearthColor.line).frame(width: Self.quoteBarWidth)
                    }
            }
        }
        .animation(.snappy, value: isExpanded)
    }

    /// "Thinking…" while it lasts, then how long it took.
    private var title: String {
        if isActive {
            return Strings.thinking
        }
        guard let seconds, seconds > 1 else {
            return Strings.thoughtBriefly
        }
        return Strings.thought(seconds: seconds)
    }
}

/// A pulsing dot shown until the first of a reply arrives.
private struct WritingIndicator: View {
    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(HearthColor.pine)
            .frame(width: HearthSize.statusDot, height: HearthSize.statusDot)
            .scaleEffect(isPulsing ? 1.25 : 0.75)
            .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear { isPulsing = true }
            .accessibilityLabel(Strings.writing)
    }
}

/// The web pages a reply was written from, each a link.
private struct SourcesSection: View {
    let sources: [SearchSource]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: HearthSpacing.s6) {
                ForEach(sources) { source in
                    let number = (sources.firstIndex(of: source) ?? 0) + 1
                    let host = source.url.host()?.replacingOccurrences(of: "www.", with: "") ?? source.title
                    Link(destination: source.url) {
                        Text("\(number)  \(host)")
                            .font(.caption)
                            .foregroundStyle(HearthColor.mute)
                            .padding(.horizontal, HearthSpacing.s10)
                            .padding(.vertical, HearthSpacing.s6)
                            .capsuleSurface()
                    }
                    .accessibilityLabel(Strings.source(number: number, host: host))
                    .accessibilityHint(source.title)
                }
            }
        }
    }
}
