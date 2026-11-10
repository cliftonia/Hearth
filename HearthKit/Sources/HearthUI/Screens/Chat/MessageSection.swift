import HearthDomain
import SwiftUI
import UIKit

/// One message in the chat: the user's in a bubble, the assistant's as open text with its extras.
struct MessageSection: View {
    let message: Message
    let isStreaming: Bool
    let isSpeaking: Bool
    let speakAction: (() -> Void)?
    let editAction: (() -> Void)?
    let retryAction: (() -> Void)?

    @State private var copyCount = 0

    var body: some View {
        switch message.role {
        case .user:
            userBubble
        case .assistant:
            assistantReply
        }
    }

    private var userBubble: some View {
        VStack(alignment: .trailing, spacing: 6) {
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
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(HearthColor.bubble, in: UnevenRoundedRectangle(cornerRadii: Self.bubbleRadii, style: .continuous))
                    .contentShape(.contextMenuPreview, UnevenRoundedRectangle(cornerRadii: Self.bubbleRadii, style: .continuous))
                    .contextMenu { userMenu }
            }
        }
        .padding(.leading, 48)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var assistantReply: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !message.thinking.isEmpty {
                ThinkingSection(thinking: message.thinking, seconds: message.thinkingSeconds, isActive: isStreaming && message.text.isEmpty)
            }
            if message.text.isEmpty, message.thinking.isEmpty, isStreaming {
                WritingIndicator()
            }
            if !message.text.isEmpty {
                MarkdownSection(markdown: message.text)
                    .textSelection(.enabled)
            }
            if !message.sources.isEmpty {
                SourcesSection(sources: message.sources)
            }
            actions
                .opacity(isStreaming || message.text.isEmpty ? 0 : 1)
                .accessibilityHidden(isStreaming || message.text.isEmpty)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

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

    private var actions: some View {
        HStack(spacing: 4) {
            actionButton(systemImage: "doc.on.doc", label: Strings.copy, action: copyAction)
            ShareLink(item: message.text) {
                Image(systemName: "square.and.arrow.up")
                    .font(.footnote)
                    .foregroundStyle(HearthColor.mute)
                    .frame(width: 34, height: 30)
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
        }
        .sensoryFeedback(.success, trigger: copyCount)
    }

    private func actionButton(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.footnote)
                .foregroundStyle(HearthColor.mute)
                .frame(width: 34, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private static let bubbleRadii = RectangleCornerRadii(topLeading: 18, bottomLeading: 18, bottomTrailing: 6, topTrailing: 18)
}

/// The model's reasoning, folded away until asked for.
private struct ThinkingSection: View {
    let thinking: String
    let seconds: Int?
    let isActive: Bool

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { isExpanded.toggle() }, label: {
                HStack(spacing: 7) {
                    Circle()
                        .fill(HearthColor.pine)
                        .frame(width: 7, height: 7)
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
                    .padding(.leading, 12)
                    .overlay(alignment: .leading) {
                        Rectangle().fill(HearthColor.line).frame(width: 2)
                    }
            }
        }
        .animation(.snappy, value: isExpanded)
    }

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

private struct WritingIndicator: View {
    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(HearthColor.pine)
            .frame(width: 10, height: 10)
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
            HStack(spacing: 6) {
                ForEach(sources) { source in
                    let number = (sources.firstIndex(of: source) ?? 0) + 1
                    let host = source.url.host()?.replacingOccurrences(of: "www.", with: "") ?? source.title
                    Link(destination: source.url) {
                        Text("\(number)  \(host)")
                            .font(.caption)
                            .foregroundStyle(HearthColor.mute)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(HearthColor.card, in: Capsule())
                            .overlay { Capsule().strokeBorder(HearthColor.line, lineWidth: 1) }
                    }
                    .accessibilityLabel(Strings.source(number: number, host: host))
                    .accessibilityHint(source.title)
                }
            }
        }
    }
}

/// A row of photo thumbnails, optionally removable.
struct PhotoStrip: View {
    private struct Photo: Identifiable {
        let id: Int
        let image: UIImage
    }

    let imagesJPEG: [Data]
    let sideLength: CGFloat
    let removeAction: ((Int) -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            ForEach(photos) { photo in
                Image(uiImage: photo.image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: sideLength, height: sideLength)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityLabel(Strings.attachedPhoto)
                    .overlay(alignment: .topTrailing) {
                        if let removeAction {
                            Button(action: { removeAction(photo.id) }, label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.body)
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(HearthColor.onPine, HearthColor.ink.opacity(0.7))
                                    .padding(4)
                            })
                            .buttonStyle(.plain)
                            .accessibilityLabel(Strings.removePhoto)
                        }
                    }
            }
        }
    }

    private var photos: [Photo] {
        imagesJPEG.enumerated().compactMap { index, data in
            UIImage(data: data).map { Photo(id: index, image: $0) }
        }
    }
}
