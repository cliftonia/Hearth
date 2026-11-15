import HearthDomain

// The way from a reply's card into the canvas, and back.
extension ChatPresenter {
    /// Opens a piece of a reply in the canvas.
    func canvasAction(_ reference: CanvasReference) {
        delegate?.chatPresenter(self, didRequestCanvasFor: reference)
    }

    /// Hands the chat back to the user as the canvas closes: VoiceOver returns to the message field.
    func takeFocus() {
        viewModel.focusRequestCount += 1
    }
}
