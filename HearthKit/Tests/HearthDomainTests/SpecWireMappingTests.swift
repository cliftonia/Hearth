import Foundation
import HearthData
@testable import HearthDomain
import Testing

/// The conversations among the wire examples of the shared `Spec` folder, read into the app's own models: the
/// defaults filled in, and identifiers written in capitals read as the lowercase ones they are.
struct SpecWireMappingTests {
    private struct WireFile: Decodable {
        let kind: String
        let id: String
        let put: Change
        let expect: Expectation
    }

    private struct Change: Decodable {
        let body: JSONValue?
    }

    private struct Expectation: Decodable {
        let deleted: Bool
        var title: String?
        var isPinned: Bool?
        var projectId: String?
        var messageIds: [String]?
    }

    @Test func `each conversation example becomes the conversation it describes`() throws {
        let names = try Spec.files(in: "wire")
        var checked = 0
        for name in names {
            let file = try Spec.load(WireFile.self, "wire/\(name)")
            guard file.kind == "conversation", !file.expect.deleted, let body = file.put.body else {
                continue
            }
            let id = Conversation.ID(try #require(UUID(uuidString: file.id)))
            let dto = try SyncWire.decode(ConversationBodyDTO.self, from: body)
            let conversation = try Conversation(from: dto, id: id, modifiedAt: Date())

            #expect(conversation.title == file.expect.title, "\(name)")
            #expect(conversation.isPinned == file.expect.isPinned, "\(name)")
            #expect(conversation.projectID?.rawValue.uuidString.lowercased() == file.expect.projectId, "\(name)")
            #expect(conversation.messages.map { $0.id.rawValue.uuidString.lowercased() } == file.expect.messageIds, "\(name)")
            #expect(!conversation.isPrivate)
            checked += 1
        }
        #expect(checked >= 5)
    }
}
