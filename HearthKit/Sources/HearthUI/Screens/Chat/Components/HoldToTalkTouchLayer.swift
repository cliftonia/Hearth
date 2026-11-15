import SwiftUI

/// A clear layer over the resting composer's field that tells a tap from a hold.
///
/// A touch that lifts quickly is a tap, and is passed on so the field can take the keyboard. One that stays is a
/// hold, which lasts until the finger lifts, slides off the field, or the touch is taken away by the system.
/// VoiceOver never meets this layer; it has the field and the microphone button.
struct HoldToTalkTouchLayer: View {
    /// How long a finger rests before it counts as holding. Anything shorter is a tap.
    private static let holdDelay = Duration.milliseconds(300)
    /// How far past the field's edge a held finger may wander before it counts as having slid off.
    private static let slideOffAllowance: CGFloat = 24

    /// Where the finger now on the layer is.
    private enum TouchKind {
        case none
        case down
        /// Still on the glass but off the field. It stays so until it lifts; sliding back does not start again.
        case slidOff
    }

    let tapAction: () -> Void
    /// Called as a finger comes to rest on the field and again when it has gone, hold or no hold.
    let pressChangedAction: (Bool) -> Void
    let holdBeganAction: () -> Void
    /// Called whenever a touch ends, whether or not it lasted long enough to be a hold.
    let holdEndedAction: () -> Void

    // A gesture state goes back to `.none` even when the system cancels the touch, which `onEnded` never reports.
    @GestureState private var touch = TouchKind.none
    @State private var holdTimer: Task<Void, Never>?
    @State private var didHoldBegin = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .contentShape(Rectangle())
                .gesture(touchGesture(in: proxy.size))
        }
        .accessibilityHidden(true)
        .onChange(of: touch) { _, touch in
            touchChanged(to: touch)
        }
        // An alert asking for the microphone, or the app being left, may swallow the lift of the finger.
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                touchChanged(to: .none)
            }
        }
        .onDisappear {
            touchChanged(to: .none)
        }
    }

    private func touchGesture(in size: CGSize) -> some Gesture {
        let field = CGRect(origin: .zero, size: size).insetBy(dx: -Self.slideOffAllowance, dy: -Self.slideOffAllowance)
        return DragGesture(minimumDistance: 0)
            .updating($touch) { value, touch, _ in
                if touch != .slidOff {
                    touch = field.contains(value.location) ? .down : .slidOff
                }
            }
            .onEnded { value in
                if !didHoldBegin, field.contains(value.location) {
                    tapAction()
                }
                // A quick tap straight after a hold must not be taken for part of that hold.
                didHoldBegin = false
            }
    }

    /// Starts the wait that turns a touch into a hold, or ends the wait and the hold when the finger has gone.
    private func touchChanged(to touch: TouchKind) {
        holdTimer?.cancel()
        holdTimer = nil
        switch touch {
        case .down:
            didHoldBegin = false
            pressChangedAction(true)
            holdTimer = Task {
                try? await Task.sleep(for: Self.holdDelay)
                guard !Task.isCancelled else {
                    return
                }
                didHoldBegin = true
                holdBeganAction()
            }
        case .none, .slidOff:
            pressChangedAction(false)
            holdEndedAction()
        }
    }
}
