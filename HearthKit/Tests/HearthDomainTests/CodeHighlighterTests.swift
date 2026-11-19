@testable import HearthDomain
import Testing

/// Telling the parts of a piece of code apart, for colouring.
struct CodeHighlighterTests {
    private func kinds(_ code: String, _ language: String?) -> [CodeToken] {
        CodeHighlighter().tokens(in: code, language: language)
    }

    private func texts(of kind: CodeTokenKind, in code: String, _ language: String?) -> [String] {
        kinds(code, language).filter { $0.kind == kind }.map(\.text)
    }

    @Test(arguments: [
        ("let total = 42 // the answer\nprint(\"done\")", "swift"),
        ("def greet(name):\n    '''Says hello.'''\n    return f\"hi {name}\"  # friendly\n", "python"),
        ("SELECT name FROM people WHERE age > 30 -- adults", "sql"),
        ("<p class=\"x\">it's</p><!-- note -->", "html"),
        ("echo \"unclosed\nnext 'line", "bash"),
        ("x = \"ends with a backslash\\", "ruby"),
        ("/* never closed", "c"),
        ("naïve = \"🙂\" // ✓", "kotlin")
    ])
    func `the tokens joined are the code unchanged`(code: String, language: String) {
        #expect(kinds(code, language).map(\.text).joined() == code)
    }

    @Test func `keywords, strings, comments and numbers are told apart`() {
        let code = "let total = 42 // the answer\nprint(\"done\")"

        #expect(texts(of: .keyword, in: code, "swift") == ["let"])
        #expect(texts(of: .number, in: code, "swift") == ["42"])
        #expect(texts(of: .comment, in: code, "swift") == ["// the answer"])
        #expect(texts(of: .string, in: code, "swift") == ["\"done\""])
    }

    @Test func `a word that only contains a keyword or a digit is left alone`() {
        let code = "letter = format2(inner)"

        #expect(kinds(code, "swift") == [CodeToken(kind: .plain, text: code)])
    }

    @Test func `each family of languages has its own comments`() {
        #expect(texts(of: .comment, in: "x = 1 # one\ny // 2", "python") == ["# one"])
        #expect(texts(of: .comment, in: "a /* b\nc */ d", "typescript") == ["/* b\nc */"])
        #expect(texts(of: .comment, in: "select 1 -- one", "sql") == ["-- one"])
        #expect(texts(of: .comment, in: "<a><!-- b --></a>", "xml") == ["<!-- b -->"])
    }

    @Test func `a string keeps its escapes, runs over lines only in three quotes, and stops at the line when unclosed`() {
        #expect(texts(of: .string, in: #"a = "say \"hi\"" + b"#, "js") == [#""say \"hi\"""#])
        #expect(texts(of: .string, in: "s = \"\"\"one\ntwo\"\"\"\nx", "python") == ["\"\"\"one\ntwo\"\"\""])
        #expect(texts(of: .string, in: "it's fine\nlet x", "swift") == ["'s fine"])
        #expect(texts(of: .keyword, in: "it's fine\nlet x", "swift") == ["let"])
    }

    @Test func `the words of SQL are keywords in either case`() {
        #expect(texts(of: .keyword, in: "Select name from people", "sql") == ["Select", "from"])
    }

    @Test(arguments: [nil, "", "text", "markdown", "output"] as [String?])
    func `code in no language, or in prose, is left plain`(language: String?) {
        #expect(kinds("let it be \"so\" // always", language) == [CodeToken(kind: .plain, text: "let it be \"so\" // always")])
    }

    @Test func `very long code is left plain and nothing gives no tokens`() {
        let long = String(repeating: "let x = 1\n", count: 2500)

        #expect(kinds(long, "swift").count == 1)
        #expect(kinds("", "swift").isEmpty)
    }
}
