import SwiftUI

extension View {
    /// Lets a small control be touched across at least `HearthSize.minimumHitTarget` on each side, as the Human
    /// Interface Guidelines ask, while it is laid out and drawn at its own size.
    ///
    /// Put it on the outermost view of the control's label, after any frame and surface.
    func minimumHitTarget() -> some View {
        contentShape(MinimumHitShape(side: HearthSize.minimumHitTarget))
    }
}

/// The view's own rectangle, grown evenly about its centre to at least `side` on each side.
///
/// A path may reach past the rectangle it is given, so the touchable area grows without moving anything around it.
private struct MinimumHitShape: Shape {
    let side: CGFloat

    func path(in rect: CGRect) -> Path {
        let horizontalGrowth = max(0, (side - rect.width) / 2)
        let verticalGrowth = max(0, (side - rect.height) / 2)
        return Path(rect.insetBy(dx: -horizontalGrowth, dy: -verticalGrowth))
    }
}
