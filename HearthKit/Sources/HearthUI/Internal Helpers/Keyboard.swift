import UIKit

enum Keyboard {
    /// Puts the keyboard away, whichever field holds it.
    @MainActor
    static func dismiss() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
