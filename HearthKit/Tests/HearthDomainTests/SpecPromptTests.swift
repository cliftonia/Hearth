import Foundation
@testable import HearthDomain
import Testing

/// The prompt vectors of the shared `Spec` folder: what the model is told, word for word, as the Android app tells it.
struct SpecPromptTests {
    private struct PromptFile: Decodable {
        let nowMilliseconds: Int64
        let timeZone: String
        let projectFence: String
        let cases: [PromptCase]
    }

    private struct PromptCase: Decodable {
        let name: String
        let input: PromptInput
        let expected: [String]
    }

    private struct PromptInput: Decodable {
        var instructions: String?
        var fullName: String?
        var nickname: String?
        var memories: [SpecMemory]?
        var isPrivate: Bool?
        var project: SpecProject?
        var style: String?
        var offersSearch: Bool?
        var offersMemory: Bool?
    }

    private struct SpecMemory: Decodable {
        let id: String
        let text: String
    }

    private struct SpecProject: Decodable {
        let name: String
        let instructions: String
        let documents: [SpecDocument]
    }

    private struct SpecDocument: Decodable {
        let name: String
        let text: String
    }

    private struct DateCase: Decodable {
        let nowMilliseconds: Int64
        let timeZone: String
        let expected: String
    }

    private static func date(_ milliseconds: Int64) -> Date {
        Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1000)
    }

    @Test func `the system message is the one in the vectors`() throws {
        let file = try Spec.load(PromptFile.self, "vectors/prompt_system.json")
        let now = Self.date(file.nowMilliseconds)
        let timeZone = try #require(TimeZone(identifier: file.timeZone))
        for vector in file.cases {
            let input = vector.input
            let project = input.project.map { project in
                Project(
                    name: project.name,
                    instructions: project.instructions,
                    documents: project.documents.map { AttachedDocument(name: $0.name, text: $0.text) }
                )
            }
            let builder = PromptBuilder(
                instructions: input.instructions ?? "",
                profile: UserProfile(fullName: input.fullName ?? "", nickname: input.nickname ?? ""),
                memories: (input.memories ?? []).map { Memory(id: Memory.ID($0.id), text: $0.text, isFromUser: false, createdAt: now, updatedAt: now) },
                isPrivate: input.isPrivate ?? false,
                project: project,
                projectFence: file.projectFence,
                timeZone: timeZone
            )
            let messages = builder.messages(
                history: [],
                sources: [],
                style: input.style == "voice" ? .voice : .chat,
                now: now,
                offersSearch: input.offersSearch ?? false,
                offersMemory: input.offersMemory ?? false
            )

            #expect(messages.first?.text == vector.expected.joined(separator: "\n\n"), "\(vector.name)")
        }
    }

    @Test func `the date is told in English in the given time zone, in research prompts too`() throws {
        let file = try Spec.load(SpecFile<DateCase>.self, "vectors/prompt_date.json")
        for vector in file.cases {
            let timeZone = try #require(TimeZone(identifier: vector.timeZone))
            let now = Self.date(vector.nowMilliseconds)
            let report = ResearchPromptBuilder(question: "Tides", now: now, timeZone: timeZone).reportMessages(notes: [])

            #expect(PromptBuilder.dateText(for: now, timeZone: timeZone) == vector.expected, "\(vector.timeZone)")
            #expect(report.first?.text == "You write clear, careful research reports from notes. Today is \(vector.expected).")
        }
    }

    @Test func `the search query is the one in the vectors`() throws {
        let file = try Spec.load(SpecFile<SpecTextCase>.self, "vectors/search_query.json")
        for vector in file.cases {
            let history = [Message(role: .assistant, text: "Earlier")] + (vector.input.map { [Message(role: .user, text: $0)] } ?? [])

            #expect(PromptBuilder(instructions: "").searchQuery(history: history) == vector.expected, "\(String(describing: vector.input))")
        }
    }
}
