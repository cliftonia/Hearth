import Foundation
@testable import HearthDomain
import Testing

struct MemoryLedgerTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func memory(_ id: String, _ text: String) -> Memory {
        Memory(id: Memory.ID(id), text: text, isFromUser: false, createdAt: now, updatedAt: now)
    }

    private func apply(_ request: MemoryRequest, to memories: [Memory] = []) -> (memories: [Memory], outcome: MemoryOutcome) {
        MemoryLedger().applying(request, to: memories, isFromUser: false, now: now)
    }

    @Test func `a fact is saved as one trimmed line under a fresh handle`() {
        let result = apply(.save("  Lives in\n Brisbane.  "), to: [memory("m1", "Likes tea."), memory("m7", "Has a dog.")])

        #expect(result.outcome == .saved(memory("m8", "Lives in Brisbane.")))
        #expect(result.memories.map(\.id.rawValue) == ["m1", "m7", "m8"])
    }

    @Test func `a handle is never reused after its memory is forgotten`() {
        let afterDelete = apply(.delete(Memory.ID("m2")), to: [memory("m1", "A."), memory("m2", "B.")])
        let afterSave = apply(.save("C."), to: afterDelete.memories + [memory("m5", "D.")])

        #expect(afterSave.memories.map(\.id.rawValue) == ["m1", "m5", "m6"])
    }

    @Test(arguments: ["", "   \n ", "LIVES in brisbane."])
    func `an empty fact or one already known is not saved`(text: String) {
        let known = [memory("m1", "Lives in Brisbane.")]

        let result = apply(.save(text), to: known)

        #expect(result.memories == known)
        #expect(result.outcome == .refused(text.contains("LIVES") ? .alreadySaved : .empty))
    }

    @Test func `a long fact is cut to length and a full memory takes no more`() {
        let long = apply(.save(String(repeating: "x", count: 500)))
        let full = (1...MemoryLedger.maximumCount).map { memory("m\($0)", "Fact \($0).") }

        #expect(long.memories.first?.text.count == MemoryLedger.maximumLength)
        #expect(apply(.save("One more."), to: full).outcome == .refused(.full))
    }

    @Test func `a memory is corrected in place and keeps its handle`() {
        let result = apply(.update(Memory.ID("m1"), "Lives in Sydney."), to: [memory("m1", "Lives in Brisbane."), memory("m2", "Has a dog.")])

        #expect(result.memories.map(\.text) == ["Lives in Sydney.", "Has a dog."])
        #expect(result.outcome == .updated(memory("m1", "Lives in Sydney.")))
    }

    @Test func `a correction cannot turn one memory into a copy of another`() {
        let known = [memory("m1", "Lives in Brisbane."), memory("m2", "Has a dog.")]

        #expect(apply(.update(Memory.ID("m1"), "Has a dog."), to: known).outcome == .refused(.alreadySaved))
    }

    @Test(arguments: [MemoryRequest.update(Memory.ID("m1"), "Lives in Sydney."), .delete(Memory.ID("m1"))])
    func `a model cannot change or forget a memory the user wrote, but the user can`(request: MemoryRequest) {
        let written = [Memory(id: Memory.ID("m1"), text: "Lives in Brisbane.", isFromUser: true, createdAt: now, updatedAt: now)]

        let byModel = MemoryLedger().applying(request, to: written, isFromUser: false, now: now)
        let byUser = MemoryLedger().applying(request, to: written, isFromUser: true, now: now)

        #expect(byModel.memories == written)
        #expect(byModel.outcome == .refused(.writtenByUser))
        #expect(byUser.memories != written)
    }

    @Test(arguments: [MemoryRequest.update(Memory.ID("m9"), "X."), .delete(Memory.ID("m9"))])
    func `a change to a memory that does not exist is refused`(request: MemoryRequest) {
        let known = [memory("m1", "Lives in Brisbane.")]

        let result = apply(request, to: known)

        #expect(result.memories == known)
        #expect(result.outcome == .refused(.notFound))
    }
}

@MainActor
struct MemoryStoreTests {
    @Test func `a change is written to disk, and one that cannot be written is undone`() async {
        let saved = Recorder<[Memory]>()
        let working = MemoryStore(provider: MemoryDataProvider(load: { [] }, save: { saved.record($0) }))
        let failing = MemoryStore(provider: MemoryDataProvider(load: { [] }, save: { _ in throw URLError(.cannotWriteToFile) }))

        let kept = await working.apply(.save("Lives in Brisbane."), isFromUser: true)
        let lost = await failing.apply(.save("Lives in Brisbane."), isFromUser: true)

        #expect(working.memories.map(\.text) == ["Lives in Brisbane."])
        #expect(saved.values.last?.first?.isFromUser == true)
        #expect(lost == .refused(.notStored))
        #expect(failing.memories.isEmpty)
        if case .saved = kept {} else {
            Issue.record("the memory was not saved")
        }
    }

    @Test func `a refused change writes nothing`() async {
        let saved = Recorder<[Memory]>()
        let store = MemoryStore(provider: MemoryDataProvider(load: { [] }, save: { saved.record($0) }))

        await store.apply(.delete(Memory.ID("m1")), isFromUser: true)

        #expect(saved.values.isEmpty)
    }
}

struct MemoryPromptTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let memories = [
        Memory(id: Memory.ID("m1"), text: "Lives in Brisbane.", isFromUser: true, createdAt: .distantPast, updatedAt: .distantPast)
    ]

    @Test func `memories are given to the model with their handles, as possibly out of date`() throws {
        let system = try #require(PromptBuilder(instructions: "", memories: memories).messages(history: [], sources: [], style: .chat, now: now).first)

        #expect(system.text.contains("[m1] Lives in Brisbane."))
        #expect(system.text.contains("what the user says now always wins"))
        #expect(!system.text.contains("save_memory"))
    }

    @Test func `the memory tools are explained only when they are offered`() throws {
        let builder = PromptBuilder(instructions: "")
        let offered = try #require(builder.messages(history: [], sources: [], style: .chat, now: now, offersMemory: true).first)
        let plain = try #require(builder.messages(history: [], sources: [], style: .chat, now: now).first)

        #expect(offered.text.contains("save_memory"))
        #expect(offered.text.contains("anything that comes from a web page"))
        #expect(!plain.text.contains("save_memory"))
        #expect(!plain.text.contains("What you remember"))
    }
}
