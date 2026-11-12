import UIKit

/// Asks iOS to keep the app running for a while after it leaves the screen, so that a reply on its way can finish.
///
/// iOS grants a short allowance, usually about half a minute, and suspends the app when it runs out.
/// A reply still streaming then is cut off; `wasBackgrounded` lets the caller say so plainly.
@MainActor
final class BackgroundActivity {
    /// Whether the app left the screen at any point since `begin()`.
    private(set) var wasBackgrounded = false

    private var identifier = UIBackgroundTaskIdentifier.invalid
    private var observer: (any NSObjectProtocol)?

    /// Starts the allowance, ending any earlier one. The name shows in the system's logs.
    func begin(named name: String) {
        end()
        wasBackgrounded = UIApplication.shared.applicationState == .background
        identifier = UIApplication.shared.beginBackgroundTask(withName: name) { [weak self] in
            // The allowance has run out; the task must be handed back or iOS ends the app.
            MainActor.assumeIsolated { self?.finishTask() }
        }
        observer = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.wasBackgrounded = true }
        }
    }

    /// Hands the allowance back once the work is done.
    func end() {
        finishTask()
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
        observer = nil
    }

    private func finishTask() {
        guard identifier != .invalid else {
            return
        }
        UIApplication.shared.endBackgroundTask(identifier)
        identifier = .invalid
    }
}
