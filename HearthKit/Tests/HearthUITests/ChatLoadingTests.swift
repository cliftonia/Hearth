import Foundation
import HearthDomain
@testable import HearthUI
import Testing

/// How the chat reads what is saved on the device as it appears, and before a background sync.
@MainActor
struct ChatLoadingTests {
    private struct Unreadable: Error {}

    private let project = Project(name: "Garden")
    private let memory = Memory(id: Memory.ID("m1"), text: "Likes tea", isFromUser: true, createdAt: Date(), updatedAt: Date())

    /// A chat presenter whose conversations cannot be read, while its projects and memories can.
    private func makeTestSubject() -> ChatPresenter {
        let (project, memory) = (project, memory)
        let conversations = ConversationStore(provider: ConversationDataProvider(
            loadAll: { throw Unreadable() },
            save: { _ in },
            delete: { _ in },
            deleteAll: {}
        ))
        let projects = ProjectStore(provider: ProjectDataProvider(loadAll: { [project] }, save: { _ in }, delete: { _ in }, deleteAll: {}))
        let memories = MemoryStore(provider: MemoryDataProvider(load: { [memory] }, save: { _ in }))
        return ChatPresenter(dependencies: ChatPresenter.Dependencies(
            chat: PresenterFixtures.chat,
            speech: PresenterFixtures.speech,
            image: PresenterFixtures.image,
            research: PresenterFixtures.research,
            dictation: PresenterFixtures.dictation,
            notifications: NotificationsFixture().provider,
            photoLibrary: PresenterFixtures.photoLibrary,
            settingsStore: PresenterFixtures.settingsStore(),
            modelStore: ModelStore(fetchModels: { _ in [] }),
            conversationStore: conversations,
            memoryStore: memories,
            projectStore: projects,
            isLocked: { false },
            isOnScreen: { true },
            announce: { _ in },
            isVoiceOverRunning: { false }
        ))
    }

    @Test func `saved data that cannot be read stops nothing else being read`() async {
        let subject = makeTestSubject()

        await subject.loadSavedData()

        #expect(subject.dependencies.conversationStore.conversations.isEmpty)
        #expect(subject.dependencies.projectStore.projects.map(\.name) == ["Garden"])
        #expect(subject.dependencies.memoryStore.memories.map(\.text) == ["Likes tea"])
    }

    @Test func `the chat still says it has loaded when part of what is saved cannot be read`() async {
        let subject = makeTestSubject()
        var loadedCount = 0
        subject.onStoresLoaded = { loadedCount += 1 }

        await subject.loadAction()

        #expect(loadedCount == 1)
        #expect(subject.dependencies.projectStore.projects.count == 1)
    }
}
