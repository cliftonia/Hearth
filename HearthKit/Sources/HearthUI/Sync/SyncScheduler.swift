import Foundation
import HearthCore
import HearthDomain
import os

/// Decides when to sync: once the app has read its data, each time it comes back to the front, a few seconds after
/// a change made here, and when the user asks. One sync runs at a time; asking during one runs one more after it.
///
/// A failure is only recorded in the `SyncStore` for the status line, never shown as an alert.
@MainActor
final class SyncScheduler {
    private let store: SyncStore
    private let interactor: SyncInteractor
    private let debounce: Duration
    private let sleep: @Sendable (Duration) async throws -> Void
    private let logger = Logger(for: SyncScheduler.self)
    private var runTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?
    private var wantsAnotherPass = false
    /// Whether the app has read its chats, projects and memories. Nothing is synced before, so that what arrives
    /// is never weighed against an empty list.
    private(set) var isReady = false

    /// - Parameters:
    ///   - debounce: How long after a change made here the sync waits, so a burst of changes is sent together.
    ///   - sleep: Waits; tests pass one that returns at once.
    init(
        store: SyncStore,
        interactor: SyncInteractor,
        debounce: Duration = .seconds(3),
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.store = store
        self.interactor = interactor
        self.debounce = debounce
        self.sleep = sleep
    }

    private var isEnabled: Bool { store.settings.isEnabled && store.settings.hubURL != nil }

    /// The app has read its data: sync for the first time, if sync is on.
    func appDidLoad() {
        isReady = true
        appBecameActive()
    }

    /// The app is back in front of the user.
    func appBecameActive() {
        guard isEnabled, isReady else {
            return
        }
        Task { await syncNow() }
    }

    /// Something changed on this device. A sync follows a few seconds later, unless another change comes first.
    func localChangeHappened() {
        guard isEnabled, isReady else {
            return
        }
        debounceTask?.cancel()
        let sleep = sleep
        let debounce = debounce
        debounceTask = Task { [weak self] in
            do {
                try await sleep(debounce)
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

    /// Stops any sync under way and any waiting to start, and waits for it to end.
    func stop() async {
        debounceTask?.cancel()
        debounceTask = nil
        wantsAnotherPass = false
        runTask?.cancel()
        await runTask?.value
    }

    /// Stops syncing and forgets everything sync knew, as erasing the device asks. Nothing is sent.
    func stopAndReset() async {
        await stop()
        await store.reset()
    }

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
