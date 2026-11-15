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

    private func makeTestSubject(hub: Hub, enabled: Bool = true) -> (SyncScheduler, SyncStore) {
        let store = PresenterFixtures.syncStore(SyncSettings(hubAddress: "http://hub.local:8765", isEnabled: enabled))
        let stores = SyncInteractor.Stores(
            conversations: PresenterFixtures.conversationStore(),
            projects: PresenterFixtures.projectStore(),
            memories: PresenterFixtures.memoryStore(),
            sync: store
        )
        let scheduler = SyncScheduler(store: store, interactor: SyncInteractor(stores: stores, provider: hub.provider), sleep: { _ in })
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
}
