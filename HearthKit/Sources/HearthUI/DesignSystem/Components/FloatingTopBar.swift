import SwiftUI

extension View {
    /// Floats the bar over the top of the view, so content scrolls on beneath it rather than stopping at its edge.
    ///
    /// iOS 26 and later soften the content under the bar with the system's scroll edge blur. Earlier systems fade it
    /// into the paper instead.
    func floatingTopBar(@ViewBuilder _ bar: () -> some View) -> some View {
        floatingBar(edge: .top, bar)
    }

    /// Floats the bar over the foot of the view, so content scrolls on beneath it and stops clear of it only when
    /// scrolled to its end.
    func floatingBottomBar(@ViewBuilder _ bar: () -> some View) -> some View {
        floatingBar(edge: .bottom, bar)
    }

    /// Has a scrolling view soften what passes beneath a floating bar at its foot, as it does at its head, rather
    /// than end it at a line. Earlier systems have no such edge, and the bar's own fade does the softening.
    @ViewBuilder
    func softScrollFoot() -> some View {
        if #available(iOS 26, *) {
            scrollEdgeEffectStyle(.soft, for: .bottom)
        } else {
            self
        }
    }

    @ViewBuilder
    private func floatingBar(edge: VerticalEdge, @ViewBuilder _ bar: () -> some View) -> some View {
        if #available(iOS 26, *) {
            safeAreaBar(edge: edge, spacing: 0, content: bar)
        } else {
            let isTop = edge == .top
            safeAreaInset(edge: edge, spacing: 0) {
                bar()
                    .background {
                        // Paper behind most of the bar, thinning to nothing at the side the content comes from.
                        LinearGradient(
                            colors: [HearthColor.paper, HearthColor.paper.opacity(0)],
                            startPoint: .init(x: 0.5, y: isTop ? 0.6 : 0.4),
                            endPoint: isTop ? .bottom : .top
                        )
                        .ignoresSafeArea(edges: isTop ? .top : .bottom)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                    }
            }
        }
    }
}
