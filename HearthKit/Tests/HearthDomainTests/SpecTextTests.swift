import Foundation
@testable import HearthDomain
import Testing

/// The text and sync vectors of the shared `Spec` folder, which the Android app's tests read too.
struct SpecTextTests {
    private struct MemoryCase: Decodable {
        let existing: [String]
        let save: String
        let expected: String
        let savedText: String?
    }

    private struct AnswerCase<Expected: Decodable>: Decodable {
        let answer: String
        let expected: Expected
    }

    private struct StampCase: Decodable {
        let milliseconds: Int64
        let writer: String

        var stamp: SyncStamp { SyncStamp(milliseconds: milliseconds, writer: writer) }
    }

    private struct LocalCase: Decodable {
        let stamp: StampCase?
        let tombstone: StampCase?
        let isBusy: Bool?
    }

    private struct DecisionCase: Decodable {
        let name: String
        let remote: StampCase
        let deleted: Bool
        let local: LocalCase
        let expected: String
    }

    @Test func `every vector file is read by a test`() throws {
        let read = [
            "follow_ups.json", "generated_title.json", "math.json", "memory_duplicates.json", "prompt_date.json", "prompt_system.json",
            "provisional_title.json", "renamed_title.json", "search_query.json", "sync_decisions.json"
        ]
        #expect(try Spec.files(in: "vectors") == read)
    }

    @Test func `a fact already remembered, whatever its case or accents, is not saved again`() throws {
        let file = try Spec.load(SpecFile<MemoryCase>.self, "vectors/memory_duplicates.json")
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        for vector in file.cases {
            let memories = vector.existing.enumerated().map { index, text in
                Memory(id: Memory.ID("m\(index + 1)"), text: text, isFromUser: false, createdAt: now, updatedAt: now)
            }
            let outcome = MemoryLedger().applying(.save(vector.save), to: memories, isFromUser: true, now: now).outcome

            switch outcome {
            case .saved(let memory):
                #expect(vector.expected == "saved", "\(vector.save)")
                #expect(memory.text == vector.savedText)
            case .refused(.alreadySaved):
                #expect(vector.expected == "alreadySaved", "\(vector.save)")
            case .refused(.empty):
                #expect(vector.expected == "empty", "\(vector.save)")
            case .refused, .updated, .deleted:
                Issue.record("\(vector.save) gave \(outcome)")
            }
        }
    }

    @Test func `titles are cut and cleaned as the vectors say`() throws {
        for vector in try Spec.load(SpecFile<SpecTextCase>.self, "vectors/provisional_title.json").cases {
            #expect(Conversation.provisionalTitle(from: vector.input ?? "") == vector.expected)
        }
        for vector in try Spec.load(SpecFile<SpecTextCase>.self, "vectors/renamed_title.json").cases {
            #expect(Conversation.renamedTitle(from: vector.input ?? "") == vector.expected, "\(String(describing: vector.input))")
        }
        for vector in try Spec.load(SpecFile<AnswerCase<String>>.self, "vectors/generated_title.json").cases {
            #expect(Conversation.generatedTitle(from: vector.answer) == vector.expected, "\(vector.answer)")
        }
    }

    @Test func `follow-up questions are read out of an answer as the vectors say`() throws {
        for vector in try Spec.load(SpecFile<AnswerCase<[String]>>.self, "vectors/follow_ups.json").cases {
            #expect(FollowUpTransformer().questions(from: vector.answer) == vector.expected, "\(vector.answer)")
        }
    }

    @Test func `maths is written out as the vectors say`() throws {
        for vector in try Spec.load(SpecFile<SpecTextCase>.self, "vectors/math.json").cases {
            #expect(MathTransformer().readableInline(vector.input ?? "") == vector.expected, "\(String(describing: vector.input))")
        }
    }

    @Test func `a received version is decided on as the vectors say`() throws {
        for vector in try Spec.load(SpecFile<DecisionCase>.self, "vectors/sync_decisions.json").cases {
            let local = SyncPlanner.LocalState(stamp: vector.local.stamp?.stamp, tombstone: vector.local.tombstone?.stamp, isBusy: vector.local.isBusy ?? false)
            let decision = SyncPlanner().decide(remote: vector.remote.stamp, isDeleted: vector.deleted, local: local)

            #expect(Self.name(of: decision) == vector.expected, "\(vector.name)")
        }
    }

    private static func name(of decision: SyncPlanner.PullDecisionKind) -> String {
        switch decision {
        case .apply:
            "apply"
        case .delete:
            "delete"
        case .keepLocal:
            "keepLocal"
        case .nothing:
            "nothing"
        case .later:
            "later"
        }
    }
}
