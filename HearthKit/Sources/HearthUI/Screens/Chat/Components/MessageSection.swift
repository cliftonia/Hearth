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
    /// What the picture server is doing while this reply is on its way.
    let pictureStatus: String?
    /// What research is doing while this reply, a report, is on its way.
    let researchStatus: String?
    /// Each action is `nil` when it does not apply to this message, and its button is then left out.
    let speakAction: (() -> Void)?
    let editAction: (() -> Void)?
    let retryAction: (() -> Void)?
    /// Shows the version of the reply at the given place, for a reply that was asked for more than once.
    let versionAction: ((Int) -> Void)?
    /// Opens the piece of work at the given place among this reply's pieces in the canvas.
    let canvasAction: (Int) -> Void
    /// Adds a picture to the photo library, answering whether it was added.
    let savePictureAction: (Data) async -> Bool

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
                    .font(.hearth(.body))
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
            if message.text.isEmpty, message.thinking.isEmpty, isStreaming, searchingQuery == nil, pictureStatus == nil, researchStatus == nil {
                WritingIndicator()
            }
            if let pictureStatus, isStreaming {
                Label(pictureStatus, systemImage: "paintbrush")
                    .font(.hearth(.footnote))
                    .foregroundStyle(HearthColor.mute)
            }
            // The steps of research show until the report itself begins to arrive.
            if let researchStatus, isStreaming, message.text.isEmpty {
                Label(researchStatus, systemImage: "text.magnifyingglass")
                    .font(.hearth(.footnote))
                    .foregroundStyle(HearthColor.mute)
            }
            if let pictureJPEG = message.imagesJPEG.first {
                PictureSection(pictureJPEG: pictureJPEG) { await savePictureAction(pictureJPEG) }
            }
            if let searchingQuery, isStreaming {
                Label(Strings.searching(for: searchingQuery), systemImage: "globe")
                    .font(.hearth(.footnote))
                    .foregroundStyle(HearthColor.mute)
                    .lineLimit(2)
            }
            if !message.text.isEmpty, message.imagesJPEG.isEmpty {
                ReplyBodySection(markdown: message.text, isStreaming: isStreaming, openAction: canvasAction)
            }
            // Under a picture the text is only a note on how it was made.
            if !message.text.isEmpty, !message.imagesJPEG.isEmpty {
                Text(message.text)
                    .font(.hearth(.footnote))
                    .foregroundStyle(HearthColor.mute)
            }
            // A report lists its sources in full once it is finished, when their numbers are settled.
            if !message.sources.isEmpty, message.isResearch, !isStreaming {
                ResearchSourcesSection(sources: ResearchSourceViewConfiguration.list(from: message.sources))
            }
            // An ordinary reply that searched the web lists its first few pages; the button beside its actions opens them all.
            if !message.sources.isEmpty, !message.isResearch, !isStreaming {
                ReplySourcesSection(sources: ResearchSourceViewConfiguration.list(from: message.sources))
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

    /// The row of buttons under a finished reply, ending in the way to its sources where it has any.
    private var actions: some View {
        HStack(spacing: HearthSpacing.s4) {
            // A picture has its own ways to be kept, and its note is not worth copying or reading out.
            if message.imagesJPEG.isEmpty {
                textActions
            }
            if let retryAction {
                actionButton(systemImage: "arrow.counterclockwise", label: Strings.tryAgain, action: retryAction)
            }
            if let versionAction, message.versionCount > 1 {
                versionStepper(versionAction)
            }
            if !message.sources.isEmpty {
                ReplySourcesButton(sources: ResearchSourceViewConfiguration.list(from: message.sources))
                    .padding(.leading, HearthSpacing.s8)
            }
        }
        .haptic(.success, trigger: copyCount)
    }

    /// Copy, share and read aloud, for a reply made of words.
    @ViewBuilder private var textActions: some View {
        actionButton(systemImage: "doc.on.doc", label: Strings.copy, action: copyAction)
        // A share link draws its own button around the label, which takes no notice of the label's touch area, so
        // the link itself is given the plain style and the 44-point area.
        ShareLink(item: message.text) {
            Image(systemName: "square.and.arrow.up")
                .font(.hearth(.footnote))
                .iconGlyphSize()
                .foregroundStyle(HearthColor.mute)
                .frame(size: HearthSize.messageAction)
                .minimumHitTarget()
                .hoverHighlight(Capsule())
        }
        .buttonStyle(.plain)
        .minimumHitTarget()
        .accessibilityLabel(Strings.share)
        .largeContentLabel(Strings.share, systemImage: "square.and.arrow.up")
        if let speakAction {
            actionButton(
                systemImage: isSpeaking ? "stop.circle" : "speaker.wave.2",
                label: isSpeaking ? Strings.stopReading : Strings.readAloud,
                action: speakAction
            )
        }
    }

    /// Steps back and forth through the versions of a reply, with the place of the one shown between the arrows.
    private func versionStepper(_ action: @escaping (Int) -> Void) -> some View {
        let index = message.versionIndex
        return HStack(spacing: 0) {
            actionButton(systemImage: "chevron.left", label: Strings.previousVersion) {
                Haptics.play(.selection)
                action(index - 1)
            }
                .disabled(index == 0)
                .opacity(index == 0 ? 0.35 : 1)
            Text(verbatim: "\(index + 1)/\(message.versionCount)")
                .font(.hearth(.footnote).monospacedDigit())
                .iconGlyphSize()
                .foregroundStyle(HearthColor.mute)
                .accessibilityLabel(Strings.versionPosition(number: index + 1, total: message.versionCount))
            actionButton(systemImage: "chevron.right", label: Strings.nextVersion) {
                Haptics.play(.selection)
                action(index + 1)
            }
                .disabled(index == message.versionCount - 1)
                .opacity(index == message.versionCount - 1 ? 0.35 : 1)
        }
    }

    private func actionButton(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.hearth(.footnote))
                .iconGlyphSize()
                .foregroundStyle(HearthColor.mute)
                .frame(size: HearthSize.messageAction)
                .minimumHitTarget()
                .hoverHighlight(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .largeContentLabel(label, systemImage: systemImage)
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: HearthSpacing.s8) {
            Button(action: { isExpanded.toggle() }, label: {
                HStack(spacing: Self.dotSpacing) {
                    Circle()
                        .fill(HearthColor.pine)
                        .frame(width: Self.dotDiameter, height: Self.dotDiameter)
                        .opacity(isActive ? 0.35 : 1)
                        .animation(isActive && !reduceMotion ? .easeInOut(duration: 0.7).repeatForever(autoreverses: true) : .default, value: isActive)
                    Text(title)
                        .font(.hearth(.footnote))
                        .foregroundStyle(HearthColor.mute)
                    Image(systemName: "chevron.right")
                        .font(.hearth(.caption2).weight(.semibold))
                        .foregroundStyle(HearthColor.mute)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            })
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityValue(isExpanded ? Strings.expanded : Strings.collapsed)
            if isExpanded {
                Text(thinking.trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(.hearth(.footnote))
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

/// A pulsing dot shown until the first of a reply arrives. With Reduce Motion on it holds still.
private struct WritingIndicator: View {
    @State private var isPulsing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Circle()
            .fill(HearthColor.pine)
            .frame(width: HearthSize.statusDot, height: HearthSize.statusDot)
            .scaleEffect(reduceMotion ? 1 : (isPulsing ? 1.25 : 0.75))
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear { isPulsing = true }
            .accessibilityLabel(Strings.writing)
    }
}
