import SwiftUI

/// A panel that slides in from the leading edge over dimmed content, by button or by drag.
struct DrawerContainer<Drawer: View, Content: View>: View {
    /// The share of the screen's width the drawer covers, up to `HearthSize.drawerMaximumWidth`.
    private static var widthFraction: CGFloat { 0.84 }
    /// How dark the content behind a fully open drawer becomes.
    private static var scrimOpacity: Double { 0.32 }

    @Binding var isOpen: Bool
    @ViewBuilder let drawer: Drawer
    @ViewBuilder let content: Content

    @GestureState private var dragTranslationX: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let width = min(proxy.size.width * Self.widthFraction, HearthSize.drawerMaximumWidth)
            // How far open the drawer is, from 0 to 1, following the finger while it is dragged.
            let progress = min(max(((isOpen ? width : 0) + dragTranslationX) / width, 0), 1)
            ZStack(alignment: .leading) {
                content
                    .accessibilityHidden(isOpen)
                HearthColor.scrim
                    .opacity(Self.scrimOpacity * progress)
                    .ignoresSafeArea()
                    .allowsHitTesting(isOpen)
                    .onTapGesture { isOpen = false }
                    .accessibilityHidden(true)
                drawer
                    .frame(width: width)
                    .offset(x: (progress - 1) * width)
                    .accessibilityHidden(!isOpen)
            }
            .simultaneousGesture(dragGesture(width: width))
            .animation(.snappy(duration: 0.28), value: isOpen)
            .animation(.interactiveSpring, value: dragTranslationX)
        }
    }

    /// A sideways drag follows the finger; on release, a flick or a drag past a third of the way settles it.
    private func dragGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 20)
            .updating($dragTranslationX) { value, state, _ in
                guard abs(value.translation.width) > abs(value.translation.height) else {
                    return
                }
                state = value.translation.width
            }
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else {
                    return
                }
                let travel = value.predictedEndTranslation.width
                if isOpen, travel < -width / 3 {
                    isOpen = false
                } else if !isOpen, travel > width / 3 {
                    isOpen = true
                }
            }
    }
}
