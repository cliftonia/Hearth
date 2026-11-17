import Foundation
import HearthCore
import HearthDomain
import os

/// Decides when to sync: once the app has read its data, each time it comes back to the front, every minute while it
/// stays there, a few seconds after a change made here, as soon as the hub's address, its token or the switch
/// changes, during a background refresh, and when the user asks. One sync runs at a time; asking during one runs one
/// more after it, except for the minute's pass, which is let go while another runs.
///
/// A failure is only recorded in the `SyncStore` for the status line, never shown as an alert.
@MainActor
final class SyncScheduler {
    /// How long the scheduler waits, and how it waits; tests pass waits they control.
    struct Timing {
        /// How long after a change made here the sync waits, so a burst of changes is sent together.
        var debounce: Duration = .seconds(3)
        /// How often a quiet pass runs while the app is in front, so another device's changes appear on their own.
        var pollInterval: Duration = .seconds(60)
        /// Waits out the debounce.
        var sleep: @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
        /// Waits until the next quiet pass is due.
        var waitForPoll: @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    }

    private let store: SyncStore
    private let interactor: SyncInteractor
    private let timing: Timing
    private let logger = Logger(for: SyncScheduler.self)
    private var runTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?
    private var pollTask: Task<Void, Never>?
    private var wantsAnotherPass = false
    /// Whether the app is in front of the user, which is when the quiet passes run.
    private var isActive = false
    /// Whether the app has read its chats, projects and memories. Nothing is synced before, so that what arrives
    /// is never weighed against an empty list.
    private(set) var isReady = false

    init(store: SyncStore, interactor: SyncInteractor, timing: Timing = Timing()) {
        self.store = store
        self.interactor = interactor
        self.timing = timing
    }

    private var isEnabled: Bool { store.settings.isActive }

    /// Whether the quiet passes are running, for tests.
    var isPolling: Bool { pollTask != nil }

    /// The app has read its data: sync for the first time, if sync is on.
    func appDidLoad() {
        isReady = true
        appBecameActive()
    }

    /// The app is back in front of the user: sync now, then every minute while it stays.
    func appBecameActive() {
        isActive = true
        guard isEnabled, isReady else {
            return
        }
        Task { await syncNow() }
        startPolling()
    }

    /// The app has left the front: the quiet passes stop until it comes back. A sync under way is left to finish.
    func appBecameInactive() {
        isActive = false
        stopPolling()
    }

    /// The hub's address, its token or the switch has changed: sync at once if sync is on, and start or stop the
    /// quiet passes to match.
    func settingsChanged() {
        guard isEnabled, isReady else {
            stopPolling()
            return
        }
        Task { await syncNow() }
        if isActive {
            startPolling()
        }
    }

    /// Something changed on this device. A sync follows a few seconds later, unless another change comes first.
    func localChangeHappened() {
        guard isEnabled, isReady else {
            return
        }
        debounceTask?.cancel()
        let timing = timing
        debounceTask = Task { [weak self] in
            do {
                try await timing.sleep(timing.debounce)
            } catch {
                return
            }
            await self?.run()
        }
    }

    /// Syncs now, as "Sync now" asks, and returns when it is done. During a sync, one more follows it.
    func syncNow() async {
        debounceTask?.cancel()
        debounceTask = nil
        await run()
    }

    /// One sync for a background refresh, which may come before the app has read anything: the data is read first
    /// with `loadStores`, then one sync runs, and the journal is written before this returns.
    func backgroundSync(loadStores: @MainActor () async -> Void) async {
        guard isEnabled else {
            return
        }
        if !isReady {
            await loadStores()
            isReady = true
        }
        await syncNow()
        await store.flush()
    }

    /// Stops any sync under way and any waiting to start, and waits for it to end.
    func stop() async {
        debounceTask?.cancel()
        debounceTask = nil
        stopPolling()
        wantsAnotherPass = false
        runTask?.cancel()
        await runTask?.value
    }

    /// Stops syncing and forgets everything sync knew, as erasing the device asks. Nothing is sent.
    func stopAndReset() async {
        await stop()
        await store.reset()
    }

    // MARK: Quiet passes

    private func startPolling() {
        guard pollTask == nil else {
            return
        }
        let timing = timing
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await timing.waitForPoll(timing.pollInterval)
                } catch {
                    return
                }
                guard let self, !Task.isCancelled, self.isActive, self.isEnabled else {
                    return
                }
                // A pass already running brings in the same changes, so this one is let go rather than queued.
                if self.runTask == nil {
                    await self.run()
                }
            }
        }
    }

    private func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    // MARK: Running

    private func run() async {
        guard isEnabled, isReady else {
            return
        }
        if let runTask {
            wantsAnotherPass = true
            await runTask.value
            return
        }
        let task = Task {
            repeat {
                wantsAnotherPass = false
                await runOnce()
            } while wantsAnotherPass && !Task.isCancelled && isEnabled
            runTask = nil
        }
        runTask = task
        await task.value
    }

    private func runOnce() async {
        store.syncDidBegin()
        do {
            let tooLarge = try await interactor.sync()
            store.syncDidEnd(failure: tooLarge > 0 ? .tooLarge(count: tooLarge) : nil, finished: true)
        } catch let error as SyncError {
            logger.notice("Sync failed: \(String(describing: error.failure), privacy: .public)")
            store.syncDidEnd(failure: error.failure, finished: false)
        } catch {
            // Stopped: how the last sync went still stands.
            store.syncDidEnd(failure: store.failure, finished: false)
        }
    }
}
