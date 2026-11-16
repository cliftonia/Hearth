import Foundation
@testable import HearthData
import Testing

/// The wire examples of the shared `Spec` folder, which the Android app's tests and the hub's read too: each is read
/// as the hub would hand it over, with the defaults, unknown fields and tombstones of the hub's docs/WIRE_FORMAT.md.
///
/// The folder is read where it stands, found from this file's own path, as `HearthDomainTests` reads its vectors.
struct SpecWireTests {
    struct WireFile: Decodable {
        let kind: String
        let id: String
        let put: JSONValue
        let expect: Expectation
    }

    struct Expectation: Decodable {
        let deleted: Bool
        var schema: Int?
        var title: String?
        var modelId: String?
        var isPinned: Bool?
        var projectId: String?
        var messageIds: [String]?
        var name: String?
        var instructions: String?
        var documentNames: [String]?
        var text: String?
        var isFromUser: Bool?
        var model: String?
        var scheduleKind: String?
        var time: String?
        var weekday: Int?
        var timeZone: String?
        var isEnabled: Bool?
        var usesWebSearch: Bool?
        var lastRunAt: Double?
        var lastRunFailed: Bool?
        var unknownBodyFields: [String]?
        var unknownMessageFields: [String]?
        var unknownDocumentFields: [String]?
    }

    /// The `Spec/wire` folder: four levels above this file (`HearthKit/Tests/HearthDataTests/SpecWireTests.swift`).
    static let folder = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Spec/wire")

    static func files() throws -> [(name: String, file: WireFile)] {
        try FileManager.default.contentsOfDirectory(atPath: folder.path).filter { $0.hasSuffix(".json") }.sorted().map { name in
            (name, try JSONDecoder().decode(WireFile.self, from: Data(contentsOf: folder.appendingPathComponent(name))))
        }
    }

    @Test func `every example is read as the hub hands it over`() throws {
        let files = try Self.files()
        #expect(files.count >= 10)
        #expect(files.contains { $0.name == "task.json" } && files.contains { $0.name == "task-weekly-run.json" })
        for (name, file) in files {
            let change = try SyncWire.decode(SyncPutDTO.self, from: file.put)
            #expect(change.deleted == file.expect.deleted, "\(name)")
            guard !change.deleted else {
                continue
            }
            let body = try #require(change.body, "\(name)")
            switch file.kind {
            case "conversation":
                try checkConversation(body, file.expect, name: name)
            case "project":
                let project = try SyncWire.decode(ProjectBodyDTO.self, from: body)
                #expect(project.name ?? "" == file.expect.name, "\(name)")
                #expect(project.instructions ?? "" == file.expect.instructions, "\(name)")
                #expect((project.documents ?? []).map { $0.name ?? "" } == file.expect.documentNames, "\(name)")
                checkUnknown(body, known: SyncWire.projectFields, file.expect, name: name)
            case "memory":
                let memory = try SyncWire.decode(MemoryBodyDTO.self, from: body)
                #expect(memory.text == file.expect.text, "\(name)")
                #expect(memory.isFromUser ?? false == file.expect.isFromUser, "\(name)")
                checkUnknown(body, known: SyncWire.memoryFields, file.expect, name: name)
            case "task":
                try checkTask(body, file.expect, name: name)
            default:
                Issue.record("\(name) is of a kind this app does not sync")
            }
        }
    }

    private func checkConversation(_ body: JSONValue, _ expect: Expectation, name: String) throws {
        let conversation = try SyncWire.decode(ConversationBodyDTO.self, from: body)
        #expect(conversation.schema == expect.schema, "\(name)")
        #expect(conversation.title ?? "" == expect.title, "\(name)")
        #expect(conversation.modelId == expect.modelId, "\(name)")
        #expect(conversation.isPinned ?? false == expect.isPinned, "\(name)")
        // Identifiers are compared as the lowercase text every platform writes; one written in capitals still reads.
        #expect(conversation.projectId?.lowercased() == expect.projectId, "\(name)")
        #expect((conversation.messages ?? []).map { $0.id.lowercased() } == expect.messageIds, "\(name)")
        checkUnknown(body, known: SyncWire.conversationFields, expect, name: name)
    }

    private func checkTask(_ body: JSONValue, _ expect: Expectation, name: String) throws {
        let task = try SyncWire.decode(TaskBodyDTO.self, from: body)
        #expect(task.title ?? "" == expect.title, "\(name)")
        #expect(task.model == expect.model, "\(name)")
        #expect(task.schedule.kind == expect.scheduleKind, "\(name)")
        #expect(task.schedule.time == expect.time, "\(name)")
        #expect(task.schedule.weekday == expect.weekday, "\(name)")
        #expect(task.schedule.timeZone == expect.timeZone, "\(name)")
        #expect(task.isEnabled ?? true == expect.isEnabled, "\(name)")
        #expect(task.usesWebSearch ?? false == expect.usesWebSearch, "\(name)")
        #expect(task.lastRunAt == expect.lastRunAt, "\(name)")
        #expect(task.lastRunFailed ?? false == expect.lastRunFailed, "\(name)")
        checkUnknown(body, known: SyncWire.taskFields, expect, name: name)
    }

    @Test func `a task is written back with every field the hub reads, its last run as null before the first`() throws {
        let files = Dictionary(uniqueKeysWithValues: try Self.files().map { ($0.name, $0.file) })
        let body = try #require(files["task.json"]?.put.objectValue?["body"])
        let task = try SyncWire.decode(TaskBodyDTO.self, from: body)

        let written = try #require(try SyncWire.json(from: task).objectValue)

        #expect(written == body.objectValue)
        #expect(written["lastRunAt"] == .null)
    }

    private func checkUnknown(_ body: JSONValue, known: Set<String>, _ expect: Expectation, name: String) {
        let kept = SyncUnknownFieldsDTO(from: body, known: known)
        #expect(kept.body.keys.sorted() == expect.unknownBodyFields, "\(name)")
        #expect(kept.messages.values.flatMap(\.keys).sorted() == (expect.unknownMessageFields ?? []), "\(name)")
        #expect(kept.documents.values.flatMap(\.keys).sorted() == (expect.unknownDocumentFields ?? []), "\(name)")
        #expect(kept.schema == expect.schema, "\(name)")
    }

    @Test func `a body with fields missing reads the same as one with them null`() throws {
        let files = Dictionary(uniqueKeysWithValues: try Self.files().map { ($0.name, $0.file) })
        let missing = try #require(files["conversation-missing-fields.json"]?.put.objectValue?["body"])
        let null = try #require(files["conversation-null-fields.json"]?.put.objectValue?["body"])

        #expect(try SyncWire.decode(ConversationBodyDTO.self, from: missing) == SyncWire.decode(ConversationBodyDTO.self, from: null))
    }
}
