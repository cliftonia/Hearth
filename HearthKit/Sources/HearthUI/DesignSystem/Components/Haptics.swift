import SwiftUI
import UIKit

/// The taps the app answers with. Each is named for how it feels, not for what caused it.
enum HapticKind: Hashable, Sendable, CaseIterable {
    /// A light tap: something was sent, pinned or switched.
    case light
    /// A softer, rounder tap: something finished by itself.
    case soft
    /// The tick of a choice moving from one thing to another.
    case selection
    /// Two rising taps: something was done and is now there, such as a copy or a picture.
    case success
    /// A caution, as something is destroyed.
    case warning
    /// Something went wrong.
    case error
}

/// The one place a haptic is played from, so that the switch in Settings silences them all.
///
/// A view either calls `Haptics.play(_:)` from a button's action or hangs `.haptic(_:trigger:)` on a value that
/// changes. On an iPad or a Mac, which have nothing to tap with, playing does nothing.
@MainActor
enum Haptics {
    /// Whether haptics are wanted. The root view keeps this in step with the switch in Settings.
    static var isEnabled = true

    /// What plays a haptic once it is known to be wanted. Tests put their own in its place.
    static var output: @MainActor (HapticKind) -> Void = Haptics.playOnDevice

    /// Plays the haptic, unless haptics are switched off.
    static func play(_ kind: HapticKind) {
        guard isEnabled else {
            return
        }
        output(kind)
    }

    static func playOnDevice(_ kind: HapticKind) {
        switch kind {
        case .light:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .soft:
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        case .selection:
            UISelectionFeedbackGenerator().selectionChanged()
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .warning:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .error:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}

extension View {
    /// Plays a haptic each time the value changes, when the condition holds for the change.
    ///
    /// - Parameter condition: Given the old value and the new; the haptic is played only when it returns `true`.
    func haptic<Value: Equatable>(
        _ kind: HapticKind,
        trigger: Value,
        when condition: @escaping (Value, Value) -> Bool = { _, _ in true }
    ) -> some View {
        onChange(of: trigger) { old, new in
            if condition(old, new) {
                Haptics.play(kind)
            }
        }
    }
}
