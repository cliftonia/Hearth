import HearthDomain

// Where the canvas opens and how it is put away.
extension AppCoordinator {
    /// The canvas reads the open chat through closures, and is told nothing else of the chat screen.
    static func makeCanvasPresenter(chatPresenter: ChatPresenter) -> CanvasPresenter {
        let chat = chatPresenter.viewModel
        return CanvasPresenter(
            messages: { chat.conversation.messages },
            streamingMessageID: { chat.isStreaming ? chat.conversation.messages.last?.id : nil }
        )
    }

    /// Opens a piece of a reply in the canvas: beside the chat on a wide screen, as a sheet on a narrow one.
    func openCanvas(_ reference: CanvasReference) {
        Keyboard.dismiss()
        canvasPresenter.open(reference)
        router.isCanvasOpen = true
    }

    /// The sheet the canvas shows in on a narrow screen has gone. If the user swiped it away the canvas closes;
    /// if it only gave way to the column of a screen grown wide, the canvas stays open there.
    func canvasSheetDidDismiss() {
        if router.isCanvasOpen, !router.isWide {
            canvasPresenter.closeAction()
        }
    }

    /// With the canvas open and no room for all three columns, the chat list is put away, so its button brings
    /// it back by closing the canvas. Returns whether that is what the button did.
    func closeCanvasForSidebar() -> Bool {
        guard router.isCanvasOpen, router.isSidebarPinned else {
            return false
        }
        let columns = CanvasLayout.columns(
            totalWidth: router.rootWidth,
            isSidebarPinned: true,
            isCanvasOpen: true,
            sidebarWidth: HearthSize.sidebarWidth
        )
        guard columns.sidebarWidth == 0 else {
            return false
        }
        canvasPresenter.closeAction()
        return true
    }
}

// MARK: - CanvasPresenterDelegate

extension AppCoordinator: CanvasPresenterDelegate {
    /// Closing gives the chat back: the chat list returns if it was put away to make room, and VoiceOver goes
    /// to the message field.
    func canvasPresenterDidClose(_ presenter: CanvasPresenter) {
        guard router.isCanvasOpen else {
            return
        }
        router.isCanvasOpen = false
        chatPresenter.takeFocus()
    }
}
