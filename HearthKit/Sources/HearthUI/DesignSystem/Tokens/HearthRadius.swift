import CoreGraphics

/// Corner radii, named for what they round. Every rounded rectangle is drawn with the continuous style.
enum HearthRadius {
    /// The highlight behind the selected chat in the list.
    static let row: CGFloat = 10
    /// Cards inside the chat: code blocks, tables, notices, thumbnails and the search field.
    static let card: CGFloat = 12
    /// The error banner above the composer.
    static let banner: CGFloat = 14
    /// The user's message bubble.
    static let bubble: CGFloat = 18
    /// The one tight corner of the bubble, pointing at its author.
    static let bubbleTail: CGFloat = 6
    /// The composer.
    static let composer: CGFloat = 24
}
