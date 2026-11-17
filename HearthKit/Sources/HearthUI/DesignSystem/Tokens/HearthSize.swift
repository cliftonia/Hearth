import SwiftUI

/// The sizes of controls and the widths that shape the layout.
enum HearthSize {
    // MARK: Lines

    /// The width of a border or divider.
    static let hairline: CGFloat = 1

    // MARK: Controls

    /// The least a control may be touched across on each side, however small it is drawn. See `minimumHitTarget()`.
    static let minimumHitTarget: CGFloat = 44

    /// The side of an `IconButton`, and of anything that must line up with one.
    static let iconButton: CGFloat = 40
    /// The side of a `GlassCircleButton`: the lone buttons at the top of the chat, each in its own bubble of glass.
    static let glassButton: CGFloat = 44
    /// The outlined buttons in the composer: attach and dictate.
    static let composerControl = CGSize(width: 34, height: 32)
    /// A switch in the composer's row of options.
    static let optionChip = CGSize(width: 38, height: 32)
    /// The diameter of the composer's send button.
    static let sendButton: CGFloat = 34
    /// A button in the row under a reply: copy, share, read aloud, try again.
    static let messageAction = CGSize(width: 34, height: 30)
    /// The buttons floating over the end of the chat list.
    static let floatingButton: CGFloat = 48
    /// The round buttons of a voice conversation.
    static let voiceButton: CGFloat = 60
    /// A dot that reports a state: the server's reach, or a reply being written.
    static let statusDot: CGFloat = 10

    // MARK: Layout

    /// The widest a line of chat grows, so that it stays readable on a large screen.
    static let readingWidth: CGFloat = 780
    /// The chat list when it sits beside the chat on a wide screen.
    static let sidebarWidth: CGFloat = 320
    /// The widest the drawer of chats opens on a narrow screen.
    static let drawerMaximumWidth: CGFloat = 340
}

extension View {
    /// A fixed frame of a size taken from `HearthSize`.
    func frame(size: CGSize) -> some View {
        frame(width: size.width, height: size.height)
    }
}
