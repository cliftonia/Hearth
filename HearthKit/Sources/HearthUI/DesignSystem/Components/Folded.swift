import SwiftUI

extension View {
    /// Keeps the view in place but folds it to nothing, unseen, untouchable and unread, while it has nothing to say.
    ///
    /// Unlike an `if`, the view keeps its identity, so it does not have to be built again when it unfolds, and a
    /// change can be animated as the view grows and fades in.
    func folded(_ isFolded: Bool) -> some View {
        opacity(isFolded ? 0 : 1)
            .frame(height: isFolded ? 0 : nil, alignment: .top)
            .clipped()
            .allowsHitTesting(!isFolded)
            .accessibilityHidden(isFolded)
    }
}
