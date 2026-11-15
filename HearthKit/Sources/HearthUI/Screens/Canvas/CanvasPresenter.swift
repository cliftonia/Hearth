import Foundation
import HearthCore
import HearthDomain
import os
import UIKit

/// What the canvas asks of the coordinator.
@MainActor
protocol CanvasPresenterDelegate: AnyObject {
    /// The canvas is done with and should be put away.
    func canvasPresenterDidClose(_ presenter: CanvasPresenter)
}

/// Runs the canvas: finds the opened piece and its versions in the open chat, and steps between them.
///
/// It keeps nothing of the pieces. Each is read from the chat's messages whenever the view asks, so the panel
/// follows a reply as it streams and is never out of step with what is saved.
@MainActor
final class CanvasPresenter {
    let viewModel = CanvasViewModel()
    weak var delegate: (any CanvasPresenterDelegate)?

    /// The messages of the open chat.
    private let messages: @MainActor () -> [Message]
    /// The reply on its way at this moment, if one is.
    private let streamingMessageID: @MainActor () -> Message.ID?
    /// Puts text on the pasteboard.
    private let copy: @MainActor (String) -> Void
    private let logger = Logger(for: CanvasPresenter.self)
    /// The pieces last read from each reply and the text they were read from, so that only a reply that has
    /// changed is read again.
    private var cache: [Message.ID: (text: String, pieces: [CanvasPiece])] = [:]

    init(
        messages: @escaping @MainActor () -> [Message],
        streamingMessageID: @escaping @MainActor () -> Message.ID?,
        copy: @escaping @MainActor (String) -> Void = { UIPasteboard.general.string = $0 }
    ) {
        self.messages = messages
        self.streamingMessageID = streamingMessageID
        self.copy = copy
    }

    // MARK: What the canvas shows

    /// The version being looked at, ready to draw; `nil` when nothing is open or the piece is no longer in the chat.
    var content: CanvasViewConfiguration? {
        guard let anchor = viewModel.anchor else {
            return nil
        }
        let replies = replies
        let versions = CanvasVersionMatcher().versions(of: anchor, in: replies)
        // A version stepped back to is kept; otherwise the newest is followed.
        guard let shown = versions.first(where: { $0 == viewModel.selected }) ?? versions.last,
              let piece = Self.piece(at: shown, in: replies),
              let number = versions.firstIndex(of: shown) else {
            return nil
        }
        let isWriting = !piece.isClosed && streamingMessageID() == shown.messageID
        return CanvasViewConfiguration(
            title: piece.displayTitle,
            detail: piece.title == nil ? piece.lineCountText : "\(piece.kind.name) · \(piece.lineCountText)",
            kind: piece.kind,
            text: piece.text,
            isWriting: isWriting,
            versionNumber: number + 1,
            versionCount: versions.count,
            mode: piece.kind.hasPreview && !isWriting ? viewModel.mode : .code
        )
    }

    /// The pieces of each reply in the chat that is made of words, in order.
    private var replies: [CanvasReply] {
        let extractor = CanvasExtractor()
        let replies = messages().filter { $0.role == .assistant && !$0.isPicture }
        var fresh: [Message.ID: (text: String, pieces: [CanvasPiece])] = [:]
        for reply in replies {
            if let known = cache[reply.id], known.text == reply.text {
                fresh[reply.id] = known
            } else {
                fresh[reply.id] = (reply.text, extractor.pieces(from: reply.text))
            }
        }
        cache = fresh
        return replies.map { CanvasReply(messageID: $0.id, pieces: fresh[$0.id]?.pieces ?? []) }
    }

    private static func piece(at reference: CanvasReference, in replies: [CanvasReply]) -> CanvasPiece? {
        replies.first { $0.messageID == reference.messageID }?.pieces.first { $0.index == reference.index }
    }

    // MARK: Opening and closing

    /// Shows a piece. If it is the newest of its versions the canvas goes on following them; an older one stays put.
    func open(_ reference: CanvasReference) {
        viewModel.anchor = reference
        viewModel.mode = .preview
        let versions = CanvasVersionMatcher().versions(of: reference, in: replies)
        viewModel.selected = versions.last == reference ? nil : reference
        logger.info("The canvas was opened, with \(versions.count, privacy: .public) versions")
    }

    func closeAction() {
        delegate?.canvasPresenterDidClose(self)
    }

    /// The chat has changed under the canvas. If the piece it was opened for is gone, as when another chat is
    /// opened or the message is edited away, the canvas closes.
    func chatChangedAction() {
        if viewModel.anchor != nil, content == nil {
            viewModel.anchor = nil
            viewModel.selected = nil
            closeAction()
        }
    }

    // MARK: In the panel

    /// Steps to the version before or after the one shown. Reaching the newest goes back to following it.
    func stepAction(by offset: Int) {
        guard let anchor = viewModel.anchor else {
            return
        }
        let versions = CanvasVersionMatcher().versions(of: anchor, in: replies)
        let shown = versions.firstIndex { $0 == viewModel.selected } ?? versions.count - 1
        guard versions.indices.contains(shown + offset) else {
            return
        }
        viewModel.selected = shown + offset == versions.count - 1 ? nil : versions[shown + offset]
    }

    /// Copies the text of the version shown, as it was written.
    func copyAction() {
        guard let content else {
            return
        }
        copy(content.text)
        viewModel.copyCount += 1
    }
}
