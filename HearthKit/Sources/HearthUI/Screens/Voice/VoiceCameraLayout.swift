import CoreGraphics

/// How the voice screen makes room for the camera's picture: the size of its card, and how far the orb shrinks.
enum VoiceCameraLayout {
    /// The card's width for each point of its height.
    static let aspectRatio: CGFloat = 4 / 3
    /// The widest the card grows, so that on an iPad it does not crowd out everything else.
    static let maximumWidth: CGFloat = 520
    /// The most of the space between the header and the buttons that the card may take, leaving the rest to the
    /// orb and the caption.
    static let heightShare: CGFloat = 0.42
    /// How large the orb is drawn while the card is showing, as a share of its usual size.
    static let orbScale: CGFloat = 0.55

    /// The card's size in the space given: as wide as the space and the limit allow, and no taller than its share.
    ///
    /// - Parameters:
    ///   - available: The space between the header and the buttons.
    ///   - margin: What is kept clear at each side of the card.
    static func cardSize(in available: CGSize, margin: CGFloat) -> CGSize {
        let width = max(0, min(available.width - margin * 2, maximumWidth))
        let height = max(0, min(width / aspectRatio, available.height * heightShare))
        return CGSize(width: (height * aspectRatio).rounded(.down), height: height.rounded(.down))
    }
}
