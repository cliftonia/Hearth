import SwiftUI
import UIKit

/// The sizes a window on the Mac may not be shrunk below.
enum WindowMinimumSize {
    /// The chat window: room for the chat list beside a chat, so shrinking it cannot break the layout.
    static let chat = CGSize(width: 720, height: 520)
    /// The settings window: room for a page of cards.
    static let settings = CGSize(width: 480, height: 520)
}

extension View {
    /// Hands the window scene this view is shown in to `action`, once the view is in a window and whenever it moves
    /// to another. Used for what only the scene can set, such as the smallest size a Mac window may be.
    func onWindowScene(_ action: @escaping @MainActor (UIWindowScene) -> Void) -> some View {
        background {
            WindowSceneReader(action: action)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        }
    }

    /// Leaves the Mac window this view is in without its name in the title bar, where the view shows the name itself.
    /// An iPhone or iPad has no title bar, and ignores it.
    func hidesWindowTitle() -> some View {
        onWindowScene { scene in
            #if targetEnvironment(macCatalyst)
            scene.titlebar?.titleVisibility = .hidden
            #endif
        }
    }

    /// Keeps the Mac window this view is in from being made smaller than `size`. An iPhone or iPad sizes its windows
    /// itself, and ignores it.
    func windowMinimumSize(_ size: CGSize) -> some View {
        onWindowScene { scene in
            #if targetEnvironment(macCatalyst)
            scene.sizeRestrictions?.minimumSize = size
            #endif
        }
    }
}

/// An empty view that reports the window scene it lands in.
private struct WindowSceneReader: UIViewRepresentable {
    let action: @MainActor (UIWindowScene) -> Void

    func makeUIView(context: Context) -> ReportingView {
        let view = ReportingView()
        view.action = action
        return view
    }

    func updateUIView(_ uiView: ReportingView, context: Context) {
        uiView.action = action
    }

    final class ReportingView: UIView {
        var action: (@MainActor (UIWindowScene) -> Void)?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if let scene = window?.windowScene {
                action?(scene)
            }
        }
    }
}
