import SwiftUI

extension View {
    /// Floats the bar over the top of the view, so content scrolls on beneath it rather than stopping at its edge.
    ///
    /// iOS 26 and later soften the content under the bar with the system's scroll edge blur. Earlier systems fade it
    /// into the paper instead.
    @ViewBuilder
    func floatingTopBar(@ViewBuilder _ bar: () -> some View) -> some View {
        if #available(iOS 26, *) {
            safeAreaBar(edge: .top, spacing: 0, content: bar)
        } else {
            safeAreaInset(edge: .top, spacing: 0) {
                bar()
                    .background {
                        LinearGradient(
                            colors: [HearthColor.paper, HearthColor.paper.opacity(0)],
                            startPoint: .init(x: 0.5, y: 0.6),
                            endPoint: .bottom
                        )
                        .ignoresSafeArea(edges: .top)
                        .accessibilityHidden(true)
                    }
            }
        }
    }
}
