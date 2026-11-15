import Foundation
import HearthData
@testable import HearthDomain
import Testing

/// What sync decides from stamps alone: which copy wins, what is put off, what is sent, and in what order.
struct SyncPlannerTests {
    private let planner = SyncPlanner()
    private static let here = "device-here"
    private static let there = "device-there"

    private func stamp(_ milliseconds: Int64, _ writer: String = "device-there") -> SyncStamp {
        SyncStamp(milliseconds: milliseconds, writer: writer)
    }

    struct DecisionCase: Sendable, CustomTestStringConvertible {
        let name: String
        let remote: Int64
        let isDeleted: Bool
        let local: SyncPlanner.LocalState
        let expected: SyncPlanner.PullDecisionKind
        var testDescription: String { name }
    }

    /// A local copy changed here at the given millisecond.
    private static func held(_ milliseconds: Int64, busy: Bool = false) -> SyncPlanner.LocalState {
        SyncPlanner.LocalState(stamp: SyncStamp(milliseconds: milliseconds, writer: here), isBusy: busy)
    }

    /// A deletion made here at the given millisecond and not yet sent.
    private static func deleted(_ milliseconds: Int64) -> SyncPlanner.LocalState {
        SyncPlanner.LocalState(tombstone: SyncStamp(milliseconds: milliseconds, writer: here))
    }

    static let decisionCases: [DecisionCase] = [
        DecisionCase(name: "new item", remote: 5, isDeleted: false, local: .init(), expected: .apply),
        DecisionCase(name: "newer remote", remote: 5, isDeleted: false, local: held(4), expected: .apply),
        DecisionCase(name: "newer local", remote: 5, isDeleted: false, local: held(6), expected: .keepLocal),
        DecisionCase(name: "same version", remote: 5, isDeleted: false, local: .init(stamp: .init(milliseconds: 5, writer: there)), expected: .nothing),
        DecisionCase(name: "remote deletion", remote: 5, isDeleted: true, local: held(4), expected: .delete),
        DecisionCase(name: "deletion of nothing", remote: 5, isDeleted: true, local: .init(), expected: .nothing),
        DecisionCase(name: "local edit after remote deletion", remote: 5, isDeleted: true, local: held(6), expected: .keepLocal),
        DecisionCase(name: "local deletion newer", remote: 5, isDeleted: false, local: deleted(6), expected: .keepLocal),
        DecisionCase(name: "remote item newer than local deletion", remote: 7, isDeleted: false, local: deleted(6), expected: .apply),
        DecisionCase(name: "busy and older", remote: 5, isDeleted: false, local: held(4, busy: true), expected: .later),
        DecisionCase(name: "busy and newer", remote: 5, isDeleted: false, local: held(6, busy: true), expected: .keepLocal)
    ]

    @Test(arguments: decisionCases)
    func `each received version is weighed against what is held`(_ decisionCase: DecisionCase) {
        let decision = planner.decide(remote: stamp(decisionCase.remote), isDeleted: decisionCase.isDeleted, local: decisionCase.local)
        #expect(decision == decisionCase.expected)
    }

    @Test func `at the same millisecond the writer that sorts later wins, byte by byte`() {
        #expect(stamp(5, "a") < stamp(5, "b"))
        #expect(stamp(5, "Z") < stamp(5, "a"))
        #expect(stamp(4, "z") < stamp(5, "a"))
        #expect(planner.decide(remote: stamp(5, "b"), isDeleted: false, local: .init(stamp: stamp(5, "a"))) == .apply)
    }

    @Test func `a local copy at the seen millisecond is the hub's version, and any other is a change made here`() {
        let seen = stamp(5_000)
        #expect(planner.localStamp(modifiedAt: WireTime.date(milliseconds: 5_000), seen: seen, installID: Self.here) == seen)
        #expect(planner.localStamp(modifiedAt: WireTime.date(milliseconds: 5_001), seen: seen, installID: Self.here) == stamp(5_001, Self.here))
    }

    @Test func `a page put off part of the way keeps the cursor before the first item put off`() {
        let at = WireTime.date(milliseconds: 9)
        let envelopes = (11...13).map { number in
            SyncEnvelopeDTO(kind: "conversation", id: "\(number)", updatedAt: at, updatedBy: "x", deleted: false, body: nil, seq: number)
        }
        let page = SyncChangesDTO(hubId: "h", items: envelopes, next: 13, hasMore: true)

        let plan = planner.plan(page: page, cursor: 10) { envelope in
            if envelope.seq == 12 {
                return Self.held(1, busy: true)
            }
            return SyncPlanner.LocalState()
        }

        #expect(plan.decisions == [.apply, .later, .apply])
        #expect((plan.cursor, plan.isHeldBack) == (11, true))
        #expect(planner.plan(page: page, cursor: 10) { _ in .init() }.cursor == 13)
        // A kind this app does not sync is passed over.
        #expect(planner.plan(page: page, cursor: 10) { _ in nil }.decisions == [.nothing, .nothing, .nothing])
    }

    @Test func `everything not yet on the hub is sent, in order, leaving out what is busy`() {
        var journal = SyncJournal(installID: Self.here)
        let unchanged = SyncItemKey(kind: .conversation, id: "c-unchanged")
        journal.seen[unchanged] = stamp(5)
        journal.tombstones[SyncItemKey(kind: .project, id: "p-gone")] = stamp(9, Self.here)
        journal.tombstones[SyncItemKey(kind: .conversation, id: "c-gone")] = stamp(9, Self.here)
        let local: [SyncItemKey: Date] = [
            unchanged: WireTime.date(milliseconds: 5),
            SyncItemKey(kind: .memory, id: "m-new"): WireTime.date(milliseconds: 7),
            SyncItemKey(kind: .conversation, id: "c-new"): WireTime.date(milliseconds: 7),
            SyncItemKey(kind: .conversation, id: "c-busy"): WireTime.date(milliseconds: 7),
            SyncItemKey(kind: .project, id: "p-new"): WireTime.date(milliseconds: 7)
        ]

        let pushes = planner.pushes(local: local, journal: journal, busy: [SyncItemKey(kind: .conversation, id: "c-busy")])

        #expect(pushes.map(\.key.id) == ["p-new", "c-new", "m-new", "c-gone", "p-gone"])
        #expect(pushes.map(\.isDeletion) == [false, false, false, true, true])
        #expect(pushes.first?.stamp == stamp(7, Self.here))
    }
}
