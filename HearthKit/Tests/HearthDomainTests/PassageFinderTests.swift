import Foundation
@testable import HearthDomain
import Testing

/// Choosing the passages of long files that bear on a question, and how the model is given them.
struct PassageFinderTests {
    private struct PassageCase: Decodable {
        let name: String
        let texts: [String]
        let question: String
        let allowance: Int
        let passageLength: Int
        let expected: [String]?
    }

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func `the shared examples choose the same passages as on Android`() throws {
        let file = try Spec.load(SpecFile<PassageCase>.self, "vectors/passages.json")
        for vector in file.cases {
            let found = PassageFinder(passageLength: vector.passageLength).excerpts(of: vector.texts, for: vector.question, allowance: vector.allowance)

            #expect(found == vector.expected, "\(vector.name)")
        }
    }

    @Test(arguments: ["", "one line", "a\n\nb\n", "\n\nleading", String(repeating: "word ", count: 90), "naïve 🙂\n" + String(repeating: "é", count: 50)])
    func `the passages of a text joined give the text back, none longer than allowed`(text: String) {
        let passages = PassageFinder(passageLength: 16).passages(of: text)

        #expect(passages.joined() == text)
        #expect(passages.allSatisfy { !$0.isEmpty && $0.count <= 16 })
    }

    @Test func `the words searched by leave out the commonest and a plural's ending`() {
        #expect(PassageFinder().terms(in: "What are the Beds for? A glass of 2 x") == ["bed", "glass"])
    }

    @Test func `a project's long files reach the model as the passages that match the question`() throws {
        let filler = String(repeating: "The garden log has nothing to say today.\n", count: 2000)
        let documents = [
            AttachedDocument(name: "log.txt", text: filler + "Slugs ate the lettuce in the north bed.\n" + filler),
            AttachedDocument(name: "paint.txt", text: "The shed is painted green.")
        ]
        let history = [Message(role: .user, text: "What happened to the lettuce?")]
        let builder = PromptBuilder(instructions: "", project: Project(name: "Garden", documents: documents), projectFence: "FENCE")

        let system = try #require(builder.messages(history: history, sources: [], style: .chat, now: now).first?.text)

        #expect(system.contains("Passages of reference file \"log.txt\":\nFENCE\n[…]\n"))
        #expect(system.contains("Slugs ate the lettuce in the north bed."))
        #expect(system.contains("Nothing was quoted from: \"paint.txt\"."))
        #expect(system.contains("Tell the user if the answer may lie in what you were not shown."))
        #expect(system.count < PromptBuilder.maximumProjectDocumentsLength + 4000)
    }

    @Test func `a follow-up is searched for together with the message it follows`() {
        let history = [
            Message(role: .user, text: "Tell me about the lettuce."),
            Message(role: .assistant, text: "It was eaten."),
            Message(role: .user, text: "And the beans?")
        ]

        #expect(PromptBuilder.question(in: history) == "Tell me about the lettuce.\nAnd the beans?")
    }

    @Test func `a long attached file is sent as the passages that match what was typed with it`() {
        let filler = String(repeating: "Nothing of note on this line.\n", count: 3000)
        let document = AttachedDocument(name: "minutes.txt", text: filler + "The budget was set at four thousand.\n" + filler)
        let message = Message(role: .user, text: "What was the budget?", documents: [document])

        let sent = PromptBuilder(instructions: "").messages(history: [message], sources: [], style: .chat, now: now).last?.text ?? ""

        #expect(sent.hasPrefix("Attached file \"minutes.txt\", too long to give you whole."))
        #expect(sent.contains("The budget was set at four thousand."))
        #expect(sent.hasSuffix("\n\nWhat was the budget?"))
        #expect(sent.count < PromptBuilder.maximumDocumentLength + 1000)
    }
}
