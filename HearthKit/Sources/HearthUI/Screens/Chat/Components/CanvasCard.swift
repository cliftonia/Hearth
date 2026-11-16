import HearthDomain
import SwiftUI

/// The words of a reply, with each piece of standalone work in it folded into a card that opens the canvas.
struct ReplyBodySection: View {
    let markdown: String
    /// Whether the reply is still on its way, in which case a piece left open is still being written.
    let isStreaming: Bool
    /// Opens the piece at the given place among the reply's pieces.
    let openAction: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: HearthSpacing.s12) {
            ForEach(CanvasExtractor().segments(from: markdown)) { segment in
                switch segment.kind {
                case .text(let text):
                    MarkdownSection(markdown: text)
                        .textSelection(.enabled)
                case .piece(let piece):
                    CanvasCard(piece: piece, isWriting: isStreaming && !piece.isClosed) { openAction(piece.index) }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A piece of standalone work in a reply, in place of its text: what it is, how long, and the way into the canvas.
struct CanvasCard: View {
    private static let iconSide: CGFloat = 36
    private static let maximumWidth: CGFloat = 420

    let piece: CanvasPiece
    /// Whether the piece is still being written by a reply on its way.
    let isWriting: Bool
    let openAction: () -> Void

    var body: some View {
        let detail = piece.title == nil ? piece.lineCountText : "\(piece.kind.name) · \(piece.lineCountText)"
        Button(action: openAction) {
            HStack(spacing: HearthSpacing.s12) {
                Image(systemName: piece.kind.systemImage)
                    .font(.hearth(.subheadline).weight(.medium))
                    .foregroundStyle(HearthColor.pine)
                    .frame(width: Self.iconSide, height: Self.iconSide)
                    .background(HearthColor.pineSoft, in: RoundedRectangle(cornerRadius: HearthRadius.row, style: .continuous))
                VStack(alignment: .leading, spacing: HearthSpacing.s2) {
                    Text(piece.displayTitle)
                        .font(.hearth(.subheadline).weight(.semibold))
                        .foregroundStyle(HearthColor.ink)
                        .lineLimit(1)
                    Text(isWriting ? "\(Strings.canvasWriting) \(piece.lineCountText)" : detail)
                        .font(.hearth(.caption).monospacedDigit())
                        .foregroundStyle(HearthColor.mute)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                // The spinner and the word share one place, so the card does not change shape as the piece ends.
                ZStack {
                    ProgressView()
                        .controlSize(.small)
                        .opacity(isWriting ? 1 : 0)
                    Text(Strings.canvasOpen)
                        .font(.hearth(.subheadline).weight(.medium))
                        .foregroundStyle(HearthColor.pine)
                        .opacity(isWriting ? 0 : 1)
                }
            }
            .padding(HearthSpacing.s12)
            .frame(maxWidth: Self.maximumWidth)
            .cardSurface()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            isWriting
                ? Strings.canvasWritingLabel(title: piece.displayTitle)
                : Strings.canvasOpenLabel(title: piece.displayTitle, detail: detail)
        )
    }
}
