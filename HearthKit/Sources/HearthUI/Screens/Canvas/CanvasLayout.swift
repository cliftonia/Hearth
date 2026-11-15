import CoreGraphics

/// How a wide screen is shared between the chat list, the chat and the canvas.
enum CanvasLayout {
    /// The share of the space beside the chat list that the canvas takes.
    static let canvasShare: CGFloat = 0.5
    /// The narrowest the chat and the canvas may each be with the chat list still beside them. With less than
    /// this for either, the chat list is put away for as long as the canvas is open.
    static let minimumColumnWidth: CGFloat = 360

    /// The widths of the columns at either side of the chat. The chat has what is left.
    struct Columns: Hashable {
        /// Zero when the chat list is put away, by the user or to make room.
        let sidebarWidth: CGFloat
        /// Zero when the canvas is closed.
        let canvasWidth: CGFloat
    }

    /// The columns for a screen of the given width.
    ///
    /// - Parameters:
    ///   - isSidebarPinned: Whether the user keeps the chat list beside the chat.
    ///   - sidebarWidth: The chat list's width when it shows.
    static func columns(totalWidth: CGFloat, isSidebarPinned: Bool, isCanvasOpen: Bool, sidebarWidth: CGFloat) -> Columns {
        guard isCanvasOpen else {
            return Columns(sidebarWidth: isSidebarPinned ? sidebarWidth : 0, canvasWidth: 0)
        }
        let hasRoomForAll = totalWidth - sidebarWidth >= minimumColumnWidth * 2
        let shownSidebarWidth = isSidebarPinned && hasRoomForAll ? sidebarWidth : 0
        let canvasWidth = (max(0, totalWidth - shownSidebarWidth) * canvasShare).rounded(.down)
        return Columns(sidebarWidth: shownSidebarWidth, canvasWidth: canvasWidth)
    }
}
