import Foundation
@testable import HearthDomain
import Testing

/// Erasing everything on the device: what goes, through which store, and what is left when something cannot go.
@MainActor
struct EraseTests {
    /// What a disk that cannot be written to throws.
    private struct DiskFull: Error {}

    /// A device that holds a chat, a project, a memory, a photo and saved settings, with the interactor that erases them.
    @MainActor
    final class Fixture {
        static let defaults = ServerSettings(ollamaAddress: "https://built-in.example")
        static let saved = ServerSettings(ollamaAddress: "https://mine.example", fullName: "Sam Example", nickname: "Sam", isLockEnabled: true)

        var conversationFiles: [Conversation] = [Conversation(title: "Holiday")]
        var projectFiles: [Project] = [Project(name: "Garden")]
        var memoryFile: [Memory] = [Memory(id: Memory.ID("m1"), text: "Lives in Brisbane", isFromUser: true, createdAt: Date(), updatedAt: Date())]
        var photoFile: Data? = Data([1, 2, 3])
        var settingsData: Data? = try? JSONEncoder().encode(Fixture.saved)
        var removedNotificationsCount = 0
        /// Whether the projects refuse to be deleted, as on a disk that cannot be written to.
        var failsProjects = false

        private(set) lazy var conversations = ConversationStore(provider: ConversationDataProvider(
            loadAll: { await self.conversationFiles },
            save: { _ in },
            delete: { _ in },
            deleteAll: { await self.setConversationFiles([]) }
        ))
        private(set) lazy var projects = ProjectStore(provider: ProjectDataProvider(
            loadAll: { await self.projectFiles },
            save: { _ in },
            delete: { id in try await self.deleteProject(id) }
        ))
        private(set) lazy var memories = MemoryStore(provider: MemoryDataProvider(
            load: { await self.memoryFile },
            save: { await self.setMemoryFile($0) }
        ))
        private(set) lazy var profile = ProfileStore(provider: ProfilePhotoProvider(
            load: { await self.photoFile },
            save: { await self.setPhotoFile($0) },
            delete: { await self.setPhotoFile(nil) }
        ))
        private(set) lazy var settings = SettingsStore(
            defaults: Fixture.defaults,
            load: { self.settingsData },
            save: { self.settingsData = $0 },
            clear: { self.settingsData = nil }
        )

        /// The interactor under test, over stores that have read what the device holds.
        func makeTestSubject() async throws -> EraseInteractor {
            try await conversations.load()
            try await projects.load()
            try await memories.load()
            try await profile.load()
            let stores = EraseInteractor.Stores(conversations: conversations, projects: projects, memories: memories, profile: profile, settings: settings)
            return EraseInteractor(stores: stores) { await self.countRemovedNotifications() }
        }

        private func setConversationFiles(_ files: [Conversation]) { conversationFiles = files }
        private func setMemoryFile(_ file: [Memory]) { memoryFile = file }
        private func setPhotoFile(_ file: Data?) { photoFile = file }
        private func countRemovedNotifications() { removedNotificationsCount += 1 }

        private func deleteProject(_ id: Project.ID) throws {
            if failsProjects { throw DiskFull() }
            projectFiles.removeAll { $0.id == id }
        }
    }

    @Test func `erasing leaves the app as on first launch`() async throws {
        let fixture = Fixture()
        let subject = try await fixture.makeTestSubject()
        #expect(fixture.settings.settings.nickname == "Sam")

        try await subject.eraseAll()

        #expect(fixture.conversations.conversations.isEmpty)
        #expect(fixture.projects.projects.isEmpty)
        #expect(fixture.memories.memories.isEmpty)
        #expect(fixture.profile.photoJPEG == nil)
        // The addresses the app was built with apply again, and nothing of the user's is left in the settings.
        #expect(fixture.settings.settings == Fixture.defaults)
        #expect(fixture.removedNotificationsCount == 1)
    }

    @Test func `nothing is left on disk for the next launch to find`() async throws {
        let fixture = Fixture()
        let subject = try await fixture.makeTestSubject()

        try await subject.eraseAll()

        #expect(fixture.conversationFiles.isEmpty)
        #expect(fixture.projectFiles.isEmpty)
        #expect(fixture.memoryFile.isEmpty)
        #expect(fixture.photoFile == nil)
        #expect(fixture.settingsData == nil)
        // A launch after erasing starts from the defaults, as a fresh install does.
        let relaunched = SettingsStore(defaults: Fixture.defaults, load: { fixture.settingsData }, save: { _ in })
        #expect(relaunched.settings == Fixture.defaults)
    }

    @Test func `when something cannot be erased the error is passed on and the settings are kept to try again`() async throws {
        let fixture = Fixture()
        let subject = try await fixture.makeTestSubject()
        fixture.failsProjects = true

        await #expect(throws: (any Error).self) {
            try await subject.eraseAll()
        }

        #expect(fixture.projects.projects.map(\.name) == ["Garden"])
        #expect(fixture.settings.settings == Fixture.saved)
        #expect(fixture.settingsData != nil)
        #expect(fixture.memories.memories.count == 1)
    }

    @Test func `a store without a way to delete everything at once deletes each in turn`() async throws {
        let fixture = Fixture()
        _ = try await fixture.makeTestSubject()

        try await fixture.projects.deleteAll()

        #expect(fixture.projects.projects.isEmpty)
        #expect(fixture.projectFiles.isEmpty)
    }

    @Test func `the profile photo is kept, replaced and removed through its store`() async throws {
        let fixture = Fixture()
        _ = try await fixture.makeTestSubject()
        #expect(fixture.profile.photoJPEG == Data([1, 2, 3]))

        try await fixture.profile.setPhoto(Data([9]))
        #expect(fixture.photoFile == Data([9]))

        try await fixture.profile.removePhoto()
        #expect(fixture.profile.photoJPEG == nil)
        #expect(fixture.photoFile == nil)
    }
}
