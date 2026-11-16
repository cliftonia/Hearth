import Foundation
import HearthCore
import os
#if !targetEnvironment(macCatalyst)
import BackgroundTasks
#endif

/// Asks the system to wake the app now and then for one sync, so that the answers to scheduled tasks arrive while it
/// is away. The system decides when; this only asks for no sooner than `earliestInterval` from now.
///
/// The identifier is listed in Info.plist under `BGTaskSchedulerPermittedIdentifiers`, and the app's scene runs the
/// refresh (`HearthApp`). A Mac keeps the app running in the background anyway, so there it does nothing.
public enum BackgroundRefresh {
    /// The refresh's identifier: the app's bundle identifier with `.sync` after it, as Info.plist lists it.
    public static var identifier: String {
        (Bundle.main.bundleIdentifier ?? "Hearth") + ".sync"
    }

    /// The soonest the next refresh may run.
    static let earliestInterval: TimeInterval = 15 * 60

    /// Asks for the next refresh, replacing any asked for before. A refusal (as in the simulator, or with background
    /// refresh turned off for the app) is logged and otherwise ignored: the app syncs when it is opened.
    static func schedule() {
        #if !targetEnvironment(macCatalyst)
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: earliestInterval)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            Logger(for: BackgroundRefresh.self).notice("A background refresh was not scheduled: \(error.localizedDescription, privacy: .public)")
        }
        #endif
    }
}
