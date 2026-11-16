import Foundation
import HearthData
import HearthDomain
@testable import HearthUI
import Testing

/// When syncs run: not before the app has read its data, not while off, and one at a time.
@MainActor
struct SyncSchedulerTests {
    /// Holds each request for changes until the test lets it go, and counts how many ran at once.
    final class Hub: @unchecked Sendable {
        private let lock = NSLock()
        private var waiting: [CheckedContinuation<Void, Never>] = []
        private var running = 0
        private(set) var calls = 0
        private(set) var mostAtOnce = 0
        var holds = false

        var provider: SyncDataProvider {
            SyncDataProvider(
                health: { _ in SyncHealthDTO(ok: true, seq: 0, hubId: "h", authRequired: false) },
                changes: { _, _, since in
                    await self.arrive()
                    return SyncChangesDTO(hubId: "h", items: [], next: since, hasMore: false)
                },
                put: { _, _, _, _ in throw URLError(.badServerResponse) }
            )
        }

        private func arrive() async {
            let mustWait = lock.withLock {
                calls += 1
                running += 1
                mostAtOnce = max(mostAtOnce, running)
                return holds
            }
            if mustWait {
                await withCheckedContinuation { continuation in
                    lock.withLock { waiting.append(continuation) }
                }
            }
            lock.withLock { running -= 1 }
        }

        var waitingCount: Int { lock.withLock { waiting.count } }

        func release() {
            let all = lock.withLock {
                holds = false
                defer { waiting = [] }
                return waiting
            }
            all.forEach { $0.resume() }
        }
    }

    /// Lets each regular pass go only when the test says, so the minute between passes takes no time at all.
    final class Ticks: @unchecked Sendable {
        private let lock = NSLock()
        private var waiting: [CheckedContinuation<Void, Never>] = []

        func next() async {
            await withCheckedContinuation { continuation in
                lock.withLock { waiting.append(continuation) }
            }
        }

        var waitingCount: Int { lock.withLock { waiting.count } }

        /// Lets every pass that is waiting go.
        func release() {
            let all = lock.withLock {
                defer { waiting = [] }
                return waiting
            }
            all.forEach { $0.resume() }
        }
    }

    /// Lets other tasks run until the condition holds, or gives up after a while.
    private func settle(until condition: () -> Bool) async {
        for _ in 0..<2_000 where !condition() {
            await Task.yield()
        }
    }

    private func makeTestSubject(hub: Hub, enabled: Bool = true, ticks: Ticks = Ticks()) -> (SyncScheduler, SyncStore) {
        let store = PresenterFixtures.syncStore(SyncSettings(hubAddress: "http://hub.local:8765", isEnabled: enabled))
        let stores = SyncInteractor.Stores(
            conversations: PresenterFixtures.conversationStore(),
            projects: PresenterFixtures.projectStore(),
            memories: PresenterFixtures.memoryStore(),
            tasks: PresenterFixtures.taskStore(),
            sync: store
        )
        // The regular passes wait for the test to let each one go; the debounce does not wait at all.
        let timing = SyncScheduler.Timing(sleep: { _ in }, waitForPoll: { _ in await ticks.next() })
        let scheduler = SyncScheduler(store: store, interactor: SyncInteractor(stores: stores, provider: hub.provider), timing: timing)
        return (scheduler, store)
    }

    @Test func `nothing syncs before the app has read its data, or while sync is off`() async {
        let hub = Hub()
        let (scheduler, _) = makeTestSubject(hub: hub)
        await scheduler.syncNow()
        #expect(hub.calls == 0)

        let (offScheduler, _) = makeTestSubject(hub: hub, enabled: false)
        offScheduler.appDidLoad()
        await offScheduler.syncNow()
        #expect(hub.calls == 0)
    }

    @Test func `a sync that finishes is recorded for the status line`() async {
        let hub = Hub()
        let (scheduler, store) = makeTestSubject(hub: hub)
        scheduler.appDidLoad()

        await scheduler.syncNow()

        #expect(hub.calls >= 1)
        #expect(store.lastSyncedAt != nil)
        #expect(store.failure == nil && !store.isSyncing)
    }

    @Test func `asking during a sync runs one more after it, never two at once`() async {
        let hub = Hub()
        hub.holds = true
        let (scheduler, _) = makeTestSubject(hub: hub)
        scheduler.appDidLoad()
        let first = Task { await scheduler.syncNow() }
        while hub.waitingCount == 0 {
            await Task.yield()
        }
        let second = Task { await scheduler.syncNow() }
        await Task.yield()

        hub.release()
        await first.value
        await second.value

        #expect(hub.mostAtOnce == 1)
        #expect(hub.calls >= 2)
    }

    @Test func `stopping and resetting turns sync off and forgets the hub`() async {
        let hub = Hub()
        let (scheduler, store) = makeTestSubject(hub: hub)
        scheduler.appDidLoad()
        await scheduler.syncNow()

        await scheduler.stopAndReset()

        #expect(store.settings == SyncSettings())
        #expect(store.journal.hubID == nil)
    }

    @Test func `while the app is in front a quiet pass runs every minute, and stops when it leaves`() async {
        let hub = Hub()
        let ticks = Ticks()
        let (scheduler, _) = makeTestSubject(hub: hub, ticks: ticks)
        scheduler.appDidLoad()
        await settle { hub.calls == 1 && ticks.waitingCount == 1 }
        #expect(hub.calls == 1)
        #expect(scheduler.isPolling)

        ticks.release()
        await settle { hub.calls == 2 && ticks.waitingCount == 1 }
        #expect(hub.calls == 2)

        scheduler.appBecameInactive()
        #expect(!scheduler.isPolling)
        ticks.release()
        await settle { false }
        #expect(hub.calls == 2)
    }

    @Test func `turning sync off stops the quiet passes, and turning it on again syncs at once`() async {
        let hub = Hub()
        let ticks = Ticks()
        let (scheduler, store) = makeTestSubject(hub: hub, ticks: ticks)
        scheduler.appDidLoad()
        await settle { hub.calls == 1 && ticks.waitingCount == 1 }

        store.update(SyncSettings(hubAddress: "http://hub.local:8765", isEnabled: false))
        scheduler.settingsChanged()
        #expect(!scheduler.isPolling)
        ticks.release()
        await settle { false }
        #expect(hub.calls == 1)

        store.update(SyncSettings(hubAddress: "http://hub.local:8765", isEnabled: true))
        scheduler.settingsChanged()
        await settle { hub.calls == 2 }
        #expect(hub.calls == 2)
        #expect(scheduler.isPolling)
    }

    @Test func `a quiet pass that falls due during a sync is let go, never run beside it`() async {
        let hub = Hub()
        let ticks = Ticks()
        let (scheduler, _) = makeTestSubject(hub: hub, ticks: ticks)
        scheduler.appDidLoad()
        await settle { hub.calls == 1 && ticks.waitingCount == 1 }

        hub.holds = true
        let running = Task { await scheduler.syncNow() }
        await settle { hub.waitingCount == 1 }
        ticks.release()
        await settle { ticks.waitingCount == 1 }
        hub.release()
        await running.value

        #expect(hub.mostAtOnce == 1)
        #expect(hub.calls == 2)
    }

    @Test func `a background refresh reads the saved data first, then syncs once`() async {
        let hub = Hub()
        let (scheduler, store) = makeTestSubject(hub: hub)
        var didLoad = false

        await scheduler.backgroundSync { didLoad = true }

        #expect(didLoad)
        #expect(scheduler.isReady)
        #expect(hub.calls == 1)
        #expect(store.lastSyncedAt != nil)
        #expect(!scheduler.isPolling)
    }
}
