import Foundation

/// What a run of characters in a piece of code is, for colouring.
public enum CodeTokenKind: Sendable, Equatable {
    case plain
    case keyword
    case string
    case comment
    case number
}

/// A run of code that is all of one kind. The tokens of a piece of code, joined, are the code unchanged.
public struct CodeToken: Sendable, Equatable {
    public let kind: CodeTokenKind
    public let text: String

    public init(kind: CodeTokenKind, text: String) {
        self.kind = kind
        self.text = text
    }
}

/// Tells the keywords, strings, comments and numbers of a piece of code apart, well enough to colour it.
///
/// It reads the code once, a character at a time, and knows only how each family of languages writes a comment and
/// which words it reserves. It does not understand the code, so an unusual construct may be coloured wrongly, but
/// never changed: what it is given is what it gives back.
public struct CodeHighlighter: Sendable {
    /// Code longer than this is left plain: colouring it would cost more than it tells the reader.
    static let maximumLength = 20_000

    public init() {}

    /// The code as runs of one kind each. Code in no language, or in one that is prose, comes back as one plain run.
    public func tokens(in code: String, language: String?) -> [CodeToken] {
        guard let grammar = CodeGrammar(language: language), code.count <= Self.maximumLength else {
            return code.isEmpty ? [] : [CodeToken(kind: .plain, text: code)]
        }
        var scanner = Scanner(characters: Array(code), grammar: grammar)
        return scanner.tokens()
    }
}

// MARK: - Reading

private struct Scanner {
    let characters: [Character]
    let grammar: CodeGrammar
    private var index = 0
    private var found: [CodeToken] = []
    private var plain = ""

    init(characters: [Character], grammar: CodeGrammar) {
        self.characters = characters
        self.grammar = grammar
    }

    mutating func tokens() -> [CodeToken] {
        while index < characters.count {
            let character = characters[index]
            if let end = commentEnd() {
                take(.comment, to: end)
            } else if grammar.quotes.contains(character) {
                take(.string, to: stringEnd(quote: character))
            } else if character.isASCII, character.isNumber, !isInsideWord {
                take(.number, to: run(from: index) { $0.isHexDigit || $0 == "." || $0 == "_" || $0 == "x" || $0 == "X" })
            } else if Self.startsWord(character), !isInsideWord {
                let end = run(from: index, while: Self.continuesWord)
                let word = String(characters[index..<end])
                if grammar.keywords.contains(grammar.isCaseSensitive ? word : word.lowercased()) {
                    take(.keyword, to: end)
                } else {
                    skip(to: end)
                }
            } else {
                skip(to: index + 1)
            }
        }
        flushPlain()
        return found
    }

    private static func startsWord(_ character: Character) -> Bool {
        character.isLetter || character == "_"
    }

    private static func continuesWord(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "_"
    }

    /// Whether the character before this one is part of a word, so that `x2` is one word and not a word and a number.
    private var isInsideWord: Bool {
        index > 0 && Self.continuesWord(characters[index - 1])
    }

    private func starts(with text: String, at start: Int) -> Bool {
        let wanted = Array(text)
        return start + wanted.count <= characters.count && Array(characters[start..<start + wanted.count]) == wanted
    }

    /// Where the comment that begins here ends, or `nil` if none begins here.
    private func commentEnd() -> Int? {
        for opener in grammar.lineComments where starts(with: opener, at: index) {
            return run(from: index) { !$0.isNewline }
        }
        for (opener, closer) in grammar.blockComments where starts(with: opener, at: index) {
            var end = index + opener.count
            while end < characters.count, !starts(with: closer, at: end) {
                end += 1
            }
            return min(end + closer.count, characters.count)
        }
        return nil
    }

    /// Where the string that begins here ends. One in three quotes, or in backticks, may run over lines; any other
    /// ends with its line if it is never closed, so that a stray apostrophe colours no more than that.
    private func stringEnd(quote: Character) -> Int {
        let triple = String(repeating: quote, count: 3)
        if quote != "`", starts(with: triple, at: index) {
            var end = index + 3
            while end < characters.count, !starts(with: triple, at: end) {
                end += characters[end] == "\\" ? 2 : 1
            }
            return min(end + 3, characters.count)
        }
        var end = index + 1
        while end < characters.count {
            let character = characters[end]
            if character == "\\" {
                end += 2
            } else if character == quote {
                return end + 1
            } else if character.isNewline, quote != "`" {
                return end
            } else {
                end += 1
            }
        }
        return characters.count
    }

    private func run(from start: Int, while isPart: (Character) -> Bool) -> Int {
        var end = start
        while end < characters.count, isPart(characters[end]) {
            end += 1
        }
        return end
    }

    private mutating func take(_ kind: CodeTokenKind, to end: Int) {
        flushPlain()
        found.append(CodeToken(kind: kind, text: String(characters[index..<end])))
        index = end
    }

    private mutating func skip(to end: Int) {
        plain.append(contentsOf: characters[index..<min(end, characters.count)])
        index = end
    }

    private mutating func flushPlain() {
        if !plain.isEmpty {
            found.append(CodeToken(kind: .plain, text: plain))
            plain = ""
        }
    }
}

// MARK: - Languages

/// How one family of languages writes comments and strings, and the words it reserves.
struct CodeGrammar {
    let lineComments: [String]
    let blockComments: [(String, String)]
    let quotes: Set<Character>
    let keywords: Set<String>
    let isCaseSensitive: Bool

    /// The grammar for a language as a reply names it; `nil` for none, and for prose such as `text` or `markdown`.
    init?(language: String?) {
        guard let name = language?.lowercased(), !name.isEmpty, !Self.prose.contains(name) else {
            return nil
        }
        // Swift, Kotlin, Java, C and its relations, JavaScript, TypeScript, Go, Rust, Dart and whatever else is not
        // listed write their comments one way.
        self = Self.families.first { $0.names.contains(name) }?.grammar ?? Self.curlyFamily
    }

    private static let prose: Set<String> = ["text", "txt", "plaintext", "plain", "markdown", "md", "output", "console", "log", "diff", "csv"]

    private static let curlyFamily = CodeGrammar(lineComments: ["//"], blockComments: [("/*", "*/")], keywords: curly)

    private static let families: [(names: Set<String>, grammar: CodeGrammar)] = [
        (["python", "py", "ruby", "rb", "r", "perl", "elixir", "nim", "julia"], CodeGrammar(lineComments: ["#"], keywords: scripting)),
        (
            ["bash", "sh", "zsh", "shell", "fish", "powershell", "ps1", "dockerfile", "makefile", "make"],
            CodeGrammar(lineComments: ["#"], keywords: shell)
        ),
        (["yaml", "yml", "toml", "ini", "conf", "properties"], CodeGrammar(lineComments: ["#"], keywords: literals)),
        (
            ["json", "jsonc", "json5"],
            CodeGrammar(lineComments: ["//"], blockComments: [("/*", "*/")], quotes: ["\""], keywords: literals)
        ),
        (
            ["sql", "postgresql", "mysql", "sqlite", "plsql"],
            CodeGrammar(lineComments: ["--"], blockComments: [("/*", "*/")], quotes: ["'", "\""], keywords: sql, isCaseSensitive: false)
        ),
        (["lua", "haskell", "hs", "elm", "ada"], CodeGrammar(lineComments: ["--"], keywords: scripting)),
        (
            ["html", "xml", "svg", "xhtml", "vue", "plist"],
            CodeGrammar(lineComments: [], blockComments: [("<!--", "-->")], quotes: ["\"", "'"], keywords: [])
        ),
        (["css", "scss", "less"], CodeGrammar(lineComments: [], blockComments: [("/*", "*/")], quotes: ["\"", "'"], keywords: []))
    ]

    private init(
        lineComments: [String],
        blockComments: [(String, String)] = [],
        quotes: Set<Character> = ["\"", "'", "`"],
        keywords: Set<String>,
        isCaseSensitive: Bool = true
    ) {
        self.lineComments = lineComments
        self.blockComments = blockComments
        self.quotes = quotes
        self.keywords = keywords
        self.isCaseSensitive = isCaseSensitive
    }

    private static let literals: Set<String> = ["true", "false", "null", "yes", "no", "on", "off"]

    private static let curly: Set<String> = [
        "abstract", "actor", "any", "as", "async", "await", "bool", "boolean", "break", "case", "catch", "char", "class", "const",
        "continue", "data", "default", "defer", "do", "double", "dyn", "else", "enum", "export", "extends", "extension", "false",
        "final", "finally", "float", "fn", "for", "from", "fun", "func", "function", "go", "guard", "if", "impl", "implements",
        "import", "in", "init", "inout", "int", "interface", "internal", "is", "let", "long", "loop", "match", "mut", "namespace",
        "new", "nil", "null", "object", "of", "open", "operator", "override", "package", "private", "protected", "protocol",
        "pub", "public", "return", "self", "sealed", "some", "static", "string", "struct", "super", "suspend", "switch", "this",
        "throw", "throws", "trait", "true", "try", "type", "typealias", "typeof", "undefined", "use", "using", "val", "var",
        "void", "when", "where", "while", "yield"
    ]

    private static let scripting: Set<String> = [
        "False", "None", "True", "and", "as", "assert", "async", "await", "begin", "break", "case", "class", "continue", "def",
        "defmodule", "del", "do", "elif", "else", "elsif", "end", "ensure", "except", "false", "finally", "fn", "for", "from",
        "function", "global", "if", "import", "in", "is", "lambda", "let", "local", "module", "nil", "nonlocal", "not", "or",
        "pass", "raise", "require", "rescue", "return", "self", "then", "true", "try", "unless", "until", "when", "where",
        "while", "with", "yield"
    ]

    private static let shell: Set<String> = [
        "case", "do", "done", "elif", "else", "esac", "exit", "export", "fi", "for", "function", "if", "in", "local", "return",
        "then", "until", "while", "FROM", "RUN", "COPY", "CMD", "ENV", "EXPOSE", "ENTRYPOINT", "WORKDIR", "ARG"
    ]

    private static let sql: Set<String> = [
        "add", "all", "alter", "and", "as", "asc", "begin", "between", "by", "case", "commit", "constraint", "count", "create",
        "default", "delete", "desc", "distinct", "drop", "else", "end", "exists", "foreign", "from", "group", "having", "if",
        "in", "index", "inner", "insert", "into", "is", "join", "key", "left", "like", "limit", "not", "null", "on", "or",
        "order", "outer", "primary", "references", "right", "rollback", "select", "set", "table", "then", "union", "unique",
        "update", "values", "view", "when", "where", "with"
    ]
}
