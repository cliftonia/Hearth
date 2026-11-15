import Foundation
import HearthData
@testable import HearthDomain
import Testing

/// Every synced model goes to the wire and back without losing anything.
struct SyncMappingTests {
    private static let when = WireTime.date(milliseconds: 1_794_821_412_345)

    /// A chat that uses everything a message can hold: versions, pictures, files, sources, research, a pin and a project.
    private static var fullConversation: Conversation {
        let source = SearchSource(title: "Tides", url: URL(string: "https://tides.example/a?b=c")!, snippet: "06:12")
        let reply = Message(
            role: .assistant,
            text: "High tide at 06:12 [1].",
            thinking: "The table says…",
            thinkingSeconds: 3,
            sources: [source],
            otherVersions: [ReplyVersion(text: "Early.", thinking: "", thinkingSeconds: nil, sources: [source])],
            versionIndex: 1,
            isResearch: true,
            createdAt: when
        )
        let question = Message(
            role: .user,
            text: "When?",
            imagesJPEG: [Data([0xFF, 0xD8, 0xFF, 0x00, 0x01])],
            documents: [AttachedDocument(name: "tides.txt", text: "06:12 1.8 m")],
            createdAt: when
        )
        return Conversation(
            title: "Tides",
            modelID: ChatModel.ID("example:latest"),
            messages: [question, reply],
            isPinned: true,
            projectID: Project.ID(UUID()),
            createdAt: when,
            updatedAt: when.addingTimeInterval(60),
            modifiedAt: when.addingTimeInterval(120)
        )
    }

    /// The body as JSON on the wire and read back, as another device would.
    private func throughTheWire<Body: Codable>(_ body: Body) throws -> Body {
        let data = try JSONEncoder().encode(try SyncWire.json(from: body))
        return try SyncWire.decode(Body.self, from: try JSONDecoder().decode(JSONValue.self, from: data))
    }

    @Test func `a conversation goes to the wire and back unchanged`() throws {
        let conversation = Self.fullConversation
        let body = try throughTheWire(ConversationBodyDTO(from: conversation))

        let back = try Conversation(from: body, id: conversation.id, modifiedAt: conversation.modifiedAt)

        #expect(back == conversation)
    }

    @Test func `identifiers and times are written as every platform reads them`() throws {
        let conversation = Self.fullConversation
        let json = try SyncWire.json(from: ConversationBodyDTO(from: conversation)).objectValue ?? [:]
        let message = json["messages"]?.arrayValue?.first?.objectValue ?? [:]

        #expect(json["projectId"]?.stringValue == conversation.projectID?.rawValue.uuidString.lowercased())
        #expect(json["createdAt"]?.stringValue == "2026-11-16T09:30:12.345Z")
        #expect(json["schema"] == .integer(1))
        #expect(message["id"]?.stringValue == conversation.messages[0].id.rawValue.uuidString.lowercased())
        #expect(message["role"]?.stringValue == "user")
        #expect(message["images"]?.arrayValue?.first?.stringValue == Data([0xFF, 0xD8, 0xFF, 0x00, 0x01]).base64EncodedString())
    }

    @Test func `a body missing its optional fields reads with their defaults`() throws {
        let json: JSONValue = .object([
            "schema": .integer(1),
            "createdAt": .string("2026-11-16T09:30:12Z"),
            "messages": .array([.object([
                "id": .string(UUID().uuidString.lowercased()), "role": .string("assistant"), "createdAt": .string("2026-11-16T09:30:12.5Z")
            ])])
        ])
        let body = try SyncWire.decode(ConversationBodyDTO.self, from: json)

        let conversation = try Conversation(from: body, id: Conversation.ID(UUID()), modifiedAt: Self.when)

        #expect((conversation.title, conversation.isPinned, conversation.projectID) == ("", false, nil))
        #expect(conversation.messages.first?.text == "")
        #expect(conversation.messages.first?.createdAt == WireTime.date(milliseconds: 1_794_821_412_500))
        #expect(conversation.updatedAt == conversation.createdAt)
    }

    @Test func `a message with a role this app does not know is not read`() {
        let dto = MessageDTO(
            id: UUID().uuidString, role: "system", text: "x", thinking: nil, thinkingSeconds: nil, sources: nil, images: nil,
            documents: nil, otherVersions: nil, versionIndex: nil, isResearch: nil, createdAt: Self.when
        )
        #expect(throws: SyncMappingError.unknownRole) { try Message(from: dto) }
    }

    @Test func `a project goes to the wire and back unchanged`() throws {
        let project = Project(
            name: "Garden", instructions: "Subtropical.", documents: [AttachedDocument(name: "beds.txt", text: "Tomatoes")],
            createdAt: Self.when, updatedAt: Self.when.addingTimeInterval(5)
        )
        let body = try throughTheWire(ProjectBodyDTO(from: project))

        #expect(Project(from: body, id: project.id, updatedAt: project.updatedAt) == project)
    }

    @Test func `a memory goes to the wire and back, keeping this device's handle`() throws {
        let memory = Memory(id: Memory.ID("m4"), text: "Lives in Brisbane", isFromUser: true, createdAt: Self.when, updatedAt: Self.when)
        let body = try throughTheWire(MemoryBodyDTO(from: memory))

        #expect(Memory(from: body, handle: memory.id, syncID: memory.syncID, updatedAt: memory.updatedAt) == memory)
    }

    @Test func `conversations and memories saved before sync are read with what sync needs`() throws {
        let conversation = try JSONDecoder().decode(Conversation.self, from: Data("""
        {"id":"\(UUID().uuidString)","title":"Old","messages":[],"createdAt":100,"updatedAt":200}
        """.utf8))
        let memory = try JSONDecoder().decode(Memory.self, from: Data("""
        {"id":"m1","text":"Old","isFromUser":true,"createdAt":100,"updatedAt":200}
        """.utf8))

        #expect(conversation.modifiedAt == conversation.updatedAt)
        #expect(memory.syncID != UUID(uuid: UUID_NULL))
    }
}
