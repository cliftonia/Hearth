import Foundation
@testable import HearthData
import Testing

struct FileStoreServiceTests {
    /// A directory whose path holds a space, as Application Support does.
    private func makeTestSubject() -> FileStoreService {
        FileStoreService(directoryURL: URL.temporaryDirectory.appending(path: "Hearth Tests \(UUID().uuidString)", directoryHint: .isDirectory))
    }

    @Test func `what is saved is loaded again`() async throws {
        let subject = makeTestSubject()

        try await subject.save(Data("one".utf8), name: "a.json")
        try await subject.save(Data("two".utf8), name: "b.json")

        let loaded = try await subject.loadAll().map { String(bytes: $0, encoding: .utf8) }
        #expect(Set(loaded) == ["one", "two"])
    }

    @Test func `saving under the same name replaces the earlier contents`() async throws {
        let subject = makeTestSubject()

        try await subject.save(Data("old".utf8), name: "a.json")
        try await subject.save(Data("new".utf8), name: "a.json")

        #expect(try await subject.loadAll() == [Data("new".utf8)])
    }

    @Test func `a deleted file is gone and deleting it again is harmless`() async throws {
        let subject = makeTestSubject()
        try await subject.save(Data("one".utf8), name: "a.json")

        try await subject.delete(name: "a.json")
        try await subject.delete(name: "a.json")

        #expect(try await subject.loadAll().isEmpty)
    }

    @Test func `nothing is loaded before anything is saved`() async throws {
        #expect(try await makeTestSubject().loadAll().isEmpty)
    }
}
