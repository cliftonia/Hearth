import Foundation
@testable import HearthDomain
import Testing

/// How projects are saved and read, and how a conversation is put in one and taken out again.
@MainActor
struct ProjectStoreTests {
    /// The stores under test, sharing one pretend disk, with a record of what was written to it.
    struct Fixture {
        let subject: ProjectStore
        let conversations: ConversationStore
        let interactor: ProjectInteractor
        let savedProjects: Recorder<Project>
        let savedConversations: Recorder<Conversation>
    }

    /// What a disk that cannot be written to throws.
    private struct DiskFull: Error {}

    /// Stores whose disk already holds the given projects and conversations.
    ///
    /// - Parameters:
    ///   - failsProjectWrites: Whether every save and delete of a project fails, as on a full disk.
    ///   - failsConversationWrites: Whether every save of a conversation fails.
    private func makeTestSubject(
        projects: [Project] = [],
        conversations: [Conversation] = [],
        failsProjectWrites: Bool = false,
        failsConversationWrites: Bool = false
    ) -> Fixture {
        let savedProjects = Recorder<Project>()
        let savedConversations = Recorder<Conversation>()
        let subject = ProjectStore(provider: ProjectDataProvider(
            loadAll: { projects },
            save: {
                if failsProjectWrites { throw DiskFull() }
                savedProjects.record($0)
            },
            delete: { _ in
                if failsProjectWrites { throw DiskFull() }
            }
        ))
        let conversationStore = ConversationStore(provider: ConversationDataProvider(
            loadAll: { conversations },
            save: {
                if failsConversationWrites { throw DiskFull() }
                savedConversations.record($0)
            },
            delete: { _ in }
        ))
        return Fixture(
            subject: subject,
            conversations: conversationStore,
            interactor: ProjectInteractor(projectStore: subject, conversationStore: conversationStore),
            savedProjects: savedProjects,
            savedConversations: savedConversations
        )
    }

    private let garden = Project(name: "Garden", updatedAt: Date(timeIntervalSince1970: 100))
    private let boat = Project(name: "Boat", updatedAt: Date(timeIntervalSince1970: 200))

    // MARK: Coding

    @Test func `a project survives a round trip through JSON`() throws {
        let project = Project(
            name: "Garden",
            instructions: "Answer in metric.",
            documents: [AttachedDocument(name: "beds.txt", text: "Four raised beds.")]
        )

        let decoded = try JSONDecoder().decode(Project.self, from: JSONEncoder().encode(project))

        #expect(decoded == project)
    }

    @Test func `a project saved with only a name and its dates still loads`() throws {
        let id = UUID()
        let json = #"{"id":"\#(id.uuidString)","name":"Legacy","createdAt":0,"updatedAt":0}"#

        let project = try JSONDecoder().decode(Project.self, from: Data(json.utf8))

        #expect(project.id == Project.ID(id))
        #expect(project.name == "Legacy")
        #expect(project.instructions.isEmpty)
        #expect(project.documents.isEmpty)
    }

    @Test func `a conversation saved before projects existed is read as being in none`() throws {
        let json = #"{"id":"\#(UUID().uuidString)","title":"Legacy","messages":[],"createdAt":0,"updatedAt":0}"#

        let conversation = try JSONDecoder().decode(Conversation.self, from: Data(json.utf8))

        #expect(conversation.title == "Legacy")
        #expect(conversation.projectID == nil)
    }

    @Test func `a conversation's project survives a round trip through JSON and other updates, and can be cleared`() throws {
        let filed = Conversation(title: "Beds").updating(project: .project(garden.id))
        #expect(filed.projectID == garden.id)
        #expect(filed.updating(title: "Raised beds").projectID == garden.id)

        let decoded = try JSONDecoder().decode(Conversation.self, from: JSONEncoder().encode(filed))

        #expect(decoded == filed)
        #expect(filed.updating(project: .noProject).projectID == nil)
    }

    // MARK: The project store

    @Test func `projects load most recently changed first and are found by identifier`() async throws {
        let fixture = makeTestSubject(projects: [garden, boat])

        try await fixture.subject.load()

        #expect(fixture.subject.projects.map(\.name) == ["Boat", "Garden"])
        #expect(fixture.subject.project(for: garden.id) == garden)
        #expect(fixture.subject.project(for: nil) == nil)
        #expect(fixture.subject.project(for: Project.ID(UUID())) == nil)
    }

    @Test func `saving creates a project or replaces it, at the top of the list`() async throws {
        let fixture = makeTestSubject(projects: [garden, boat])
        try await fixture.subject.load()
        let shed = Project(name: "Shed")

        try await fixture.subject.save(shed)
        try await fixture.subject.save(garden.updating(name: "Kitchen garden"))

        #expect(fixture.subject.projects.map(\.name) == ["Kitchen garden", "Shed", "Boat"])
        #expect(fixture.savedProjects.values.map(\.name) == ["Shed", "Kitchen garden"])
    }

    @Test func `deleting removes a project from the list`() async throws {
        let fixture = makeTestSubject(projects: [garden, boat])
        try await fixture.subject.load()

        try await fixture.subject.delete(boat.id)

        #expect(fixture.subject.projects.map(\.name) == ["Garden"])
    }

    @Test func `a failed save or delete leaves the projects as they are on disk`() async throws {
        let fixture = makeTestSubject(projects: [garden, boat], failsProjectWrites: true)
        try await fixture.subject.load()

        await #expect(throws: DiskFull.self) { try await fixture.subject.save(garden.updating(name: "Changed")) }
        await #expect(throws: DiskFull.self) { try await fixture.subject.save(Project(name: "Brand new")) }
        await #expect(throws: DiskFull.self) { try await fixture.subject.delete(boat.id) }

        #expect(fixture.subject.projects.map(\.name) == ["Boat", "Garden"])
    }

    // MARK: Conversations in a project

    @Test func `a chat is put in a project and taken out again without changing its place by date`() async throws {
        let chat = Conversation(title: "Beds", updatedAt: Date(timeIntervalSince1970: 50))
        let fixture = makeTestSubject(conversations: [chat])
        try await fixture.conversations.load()

        try await fixture.conversations.setProject(garden.id, for: chat.id)
        #expect(fixture.conversations.conversation(for: chat.id)?.projectID == garden.id)
        try await fixture.conversations.setProject(nil, for: chat.id)

        #expect(fixture.conversations.conversation(for: chat.id)?.projectID == nil)
        #expect(fixture.savedConversations.values.map(\.projectID) == [garden.id, nil])
        #expect(fixture.savedConversations.values.map(\.updatedAt) == [chat.updatedAt, chat.updatedAt])
    }

    @Test func `saving a copy made before the move does not undo it, and a new chat keeps the project it began in`() async throws {
        let chat = Conversation(title: "Beds")
        let fixture = makeTestSubject(conversations: [chat])
        try await fixture.conversations.load()
        try await fixture.conversations.setProject(garden.id, for: chat.id)

        try await fixture.conversations.save(chat.updating(title: "Raised beds"))
        let begun = Conversation(title: "Compost", projectID: garden.id)
        try await fixture.conversations.save(begun)

        #expect(fixture.conversations.conversation(for: chat.id)?.projectID == garden.id)
        #expect(fixture.conversations.conversation(for: chat.id)?.title == "Raised beds")
        #expect(fixture.conversations.conversation(for: begun.id)?.projectID == garden.id)
    }

    @Test func `a failed move is undone`() async throws {
        let chat = Conversation(title: "Beds", projectID: garden.id)
        let fixture = makeTestSubject(conversations: [chat], failsConversationWrites: true)
        try await fixture.conversations.load()

        await #expect(throws: DiskFull.self) { try await fixture.conversations.setProject(boat.id, for: chat.id) }

        #expect(fixture.conversations.conversation(for: chat.id)?.projectID == garden.id)
    }

    // MARK: Deleting a project

    @Test func `deleting a project keeps its chats, which stop belonging to it`() async throws {
        let inGarden = [Conversation(title: "Beds", projectID: garden.id), Conversation(title: "Compost", projectID: garden.id)]
        let others = [Conversation(title: "Hull", projectID: boat.id), Conversation(title: "Loose")]
        let fixture = makeTestSubject(projects: [garden, boat], conversations: inGarden + others)
        try await fixture.subject.load()
        try await fixture.conversations.load()

        try await fixture.interactor.delete(garden.id)

        #expect(fixture.subject.projects.map(\.name) == ["Boat"])
        #expect(fixture.conversations.conversations.count == 4)
        #expect(Set(fixture.savedConversations.values.map(\.title)) == ["Beds", "Compost"])
        #expect(fixture.savedConversations.values.allSatisfy { $0.projectID == nil })
        #expect(fixture.conversations.conversations.filter { $0.projectID == boat.id }.map(\.title) == ["Hull"])
        #expect(fixture.conversations.conversations.contains { $0.projectID == garden.id } == false)
    }

    @Test func `a project whose chats cannot be let go is not deleted`() async throws {
        let chat = Conversation(title: "Beds", projectID: garden.id)
        let fixture = makeTestSubject(projects: [garden], conversations: [chat], failsConversationWrites: true)
        try await fixture.subject.load()
        try await fixture.conversations.load()

        await #expect(throws: DiskFull.self) { try await fixture.interactor.delete(garden.id) }

        #expect(fixture.subject.projects == [garden])
        #expect(fixture.conversations.conversation(for: chat.id)?.projectID == garden.id)
    }
}
