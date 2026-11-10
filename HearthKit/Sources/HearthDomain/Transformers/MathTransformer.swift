import Foundation

/// Rewrites LaTeX maths as plain Unicode text that reads well in a line: `x^2 \leq \frac{a}{b}` becomes `x² ≤ a/b`.
///
/// This is a readable approximation, not typesetting: fractions are written on one line and
/// constructs with no plain-text form, such as matrices, are left close to how they were written.
public struct MathTransformer: Sendable {
    public init() {}

    /// Replaces the maths inside `\( \)`, `$$ $$` and `$ $` in a line of prose, leaving the rest untouched.
    public func readableInline(_ text: String) -> String {
        guard text.contains("$") || text.contains("\\(") else {
            return text
        }
        var result = text
        // A single dollar pair counts as maths only when it hugs its contents and they look like maths,
        // so that prices such as "$5 and $10" are left alone.
        let patterns = [
            #"\\\((.+?)\\\)"#,
            #"\$\$(.+?)\$\$"#,
            #"(?<![\\$\w])\$(?!\s)([^$\n]*[\\^_={][^$\n]*?)(?<!\s)\$(?!\d)"#
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else {
                continue
            }
            let range = NSRange(result.startIndex..., in: result)
            for match in regex.matches(in: result, range: range).reversed() {
                guard let whole = Range(match.range, in: result), let inner = Range(match.range(at: 1), in: result) else {
                    continue
                }
                result.replaceSubrange(whole, with: readable(String(result[inner])))
            }
        }
        return result
    }

    /// Rewrites one piece of LaTeX maths, given without its delimiters.
    public func readable(_ latex: String) -> String {
        var text = latex
        // Fractions and roots may be nested, so those patterns are applied until they no longer match.
        text = replacing(#"\\(?:text|mathrm|mathbf|mathit|operatorname|boxed)\s*\{([^{}]*)\}"#, in: text, passes: 4) { $0[1] }
        text = replacing(#"\\sqrt\s*\{([^{}]*)\}"#, in: text, passes: 4) { "√(\($0[1]))" }
        text = replacing(#"\\d?frac\s*\{([^{}]*)\}\s*\{([^{}]*)\}"#, in: text, passes: 4) { groups in
            "\(Self.grouped(groups[1]))/\(Self.grouped(groups[2]))"
        }
        text = replacing(#"\\([A-Za-z]+)"#, in: text) { Self.symbols[$0[1]] ?? $0[1] }
        text = replacing(#"\\[,;:! ]"#, in: text) { _ in " " }
        text = replacing(#"\^\s*(?:\{([^{}]*)\}|(\S))"#, in: text) { groups in
            Self.script(groups[1].isEmpty ? groups[2] : groups[1], table: Self.superscripts, marker: "^")
        }
        text = replacing(#"_\s*(?:\{([^{}]*)\}|(\S))"#, in: text) { groups in
            Self.script(groups[1].isEmpty ? groups[2] : groups[1], table: Self.subscripts, marker: "_")
        }
        text = text.replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: "")
        return text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// Replaces every match of the pattern with what the closure makes of its groups; group 0 is the whole match.
    private func replacing(_ pattern: String, in text: String, passes: Int = 1, with replacement: ([String]) -> String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return text
        }
        var result = text
        for _ in 0..<passes {
            let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
            guard !matches.isEmpty else {
                break
            }
            for match in matches.reversed() {
                guard let whole = Range(match.range, in: result) else {
                    continue
                }
                let groups = (0..<match.numberOfRanges).map { index in
                    Range(match.range(at: index), in: result).map { String(result[$0]) } ?? ""
                }
                result.replaceSubrange(whole, with: replacement(groups))
            }
        }
        return result
    }

    /// A numerator or denominator, bracketed unless it is a single term.
    private static func grouped(_ term: String) -> String {
        let trimmed = term.trimmingCharacters(in: .whitespaces)
        return trimmed.allSatisfy { $0.isLetter || $0.isNumber || $0 == "." } ? trimmed : "(\(trimmed))"
    }

    /// Raised or lowered characters where Unicode has them all, otherwise the marker and brackets.
    private static func script(_ content: String, table: [Character: Character], marker: String) -> String {
        let mapped = content.compactMap { table[$0] }
        if mapped.count == content.count {
            return String(mapped)
        }
        return content.count == 1 ? marker + content : "\(marker)(\(content))"
    }

    private static let superscripts: [Character: Character] = [
        "0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴", "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹",
        "+": "⁺", "-": "⁻", "=": "⁼", "(": "⁽", ")": "⁾", "n": "ⁿ", "i": "ⁱ"
    ]

    private static let subscripts: [Character: Character] = [
        "0": "₀", "1": "₁", "2": "₂", "3": "₃", "4": "₄", "5": "₅", "6": "₆", "7": "₇", "8": "₈", "9": "₉",
        "+": "₊", "-": "₋", "=": "₌", "(": "₍", ")": "₎",
        "a": "ₐ", "e": "ₑ", "i": "ᵢ", "j": "ⱼ", "k": "ₖ", "m": "ₘ", "n": "ₙ", "o": "ₒ", "t": "ₜ", "x": "ₓ"
    ]

    private static let symbols: [String: String] = [
        "times": "×", "cdot": "·", "div": "÷", "pm": "±", "mp": "∓",
        "leq": "≤", "le": "≤", "geq": "≥", "ge": "≥", "neq": "≠", "ne": "≠", "approx": "≈", "equiv": "≡", "sim": "∼", "propto": "∝",
        "infty": "∞", "to": "→", "rightarrow": "→", "leftarrow": "←", "Rightarrow": "⇒", "Leftarrow": "⇐", "leftrightarrow": "↔",
        "sum": "∑", "prod": "∏", "int": "∫", "partial": "∂", "nabla": "∇", "sqrt": "√",
        "in": "∈", "notin": "∉", "subset": "⊂", "subseteq": "⊆", "cup": "∪", "cap": "∩", "emptyset": "∅",
        "forall": "∀", "exists": "∃", "neg": "¬", "land": "∧", "lor": "∨", "angle": "∠", "perp": "⊥", "parallel": "∥",
        "circ": "∘", "degree": "°", "ldots": "…", "cdots": "⋯", "dots": "…", "prime": "′",
        "left": "", "right": "", "quad": " ", "qquad": " ", "displaystyle": "", "limits": "",
        "alpha": "α", "beta": "β", "gamma": "γ", "delta": "δ", "epsilon": "ε", "varepsilon": "ε", "zeta": "ζ", "eta": "η",
        "theta": "θ", "iota": "ι", "kappa": "κ", "lambda": "λ", "mu": "μ", "nu": "ν", "xi": "ξ", "pi": "π", "rho": "ρ",
        "sigma": "σ", "tau": "τ", "upsilon": "υ", "phi": "φ", "varphi": "φ", "chi": "χ", "psi": "ψ", "omega": "ω",
        "Gamma": "Γ", "Delta": "Δ", "Theta": "Θ", "Lambda": "Λ", "Xi": "Ξ", "Pi": "Π", "Sigma": "Σ", "Phi": "Φ", "Psi": "Ψ", "Omega": "Ω"
    ]
}
