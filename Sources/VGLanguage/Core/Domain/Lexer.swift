import VGraph

/// A `//` comment set aside by the lexer, `text` verbatim including the marker.
/// `isTrailing` means a token preceded it on the same line.
struct LexedComment {
    let text: String
    let line: Int
    let isTrailing: Bool
}

class Lexer {
    /// The source materialised as a `[Character]` **once** at init. Token offsets
    /// are character indices into this array (see `Token.start`/`end`), so all
    /// scanning indexes `chars` directly. Materialising per access — `Array(source)`
    /// inside `advance`/`peek`/… — made a single scan O(n²) with a large
    /// Embedded-Swift grapheme constant, which dominated the editor's
    /// per-keystroke cost. Doing it once keeps the scan O(n).
    private let chars: [Character]
    private var tokens: [Token] = []
    private var start = 0
    private var current = 0
    private var line = 1

    /// Kept out of the token stream so the parser's `check`/`match`/`peek` never
    /// have to hop over them. Blank lines are *not* recorded — a gap between two
    /// entries' line numbers is what a blank line looks like.
    private(set) var comments: [LexedComment] = []

    init(source: String) {
        self.chars = Array(source)
    }

    func scanTokens() -> [Token] {
        while !isAtEnd() {
            start = current
            scanToken()
        }

        tokens.append(Token(type: .eof, lexeme: "", line: line, start: current, end: current))
        return tokens
    }

    private func scanToken() {
        let c = advance()

        switch c {
        case ";": addToken(.semicolon)
        case ":": addToken(.colon)
        case ",": addToken(.comma)
        case "{": addToken(.leftBrace)
        case "}": addToken(.rightBrace)
        case "[": addToken(.leftBracket)
        case "]": addToken(.rightBracket)
        case "(": addToken(.leftParen)
        case ")": addToken(.rightParen)
        case " ", "\r", "\t", "\n":
            if c == "\n" { line += 1 }
        case "/":
            if match("/") {
                while peek() != "\n" && !isAtEnd() {
                    _ = advance()
                }
                comments.append(
                    LexedComment(
                        text: String(chars[start..<current]).trimmingWhitespace(),
                        line: line,
                        isTrailing: tokens.last?.line == line))
            } else {
                // Single slash is not a valid token
                addToken(.unknown)
            }
        case "-":
            if match(">") {
                addToken(.arrow)
            } else {
                // Could be a negative number or part of an identifier
                if isDigit(peek()) {
                    number()
                } else {
                    identifier()
                }
            }
        case "\"": string()
        case "0", "1", "2", "3", "4", "5", "6", "7", "8", "9":
            number()
        case "_":
            identifier()
        default:
            if isAlpha(c) {
                identifier()
            } else {
                addToken(.unknown)
            }
        }
    }

    private func number() {
        while isDigit(peek()) {
            _ = advance()
        }

        if peek() == "." && isDigit(peekNext()) {
            _ = advance()

            while isDigit(peek()) {
                _ = advance()
            }
        }

        addToken(.number)
    }

    private func identifier() {
        while isAlphaNumeric(peek()) || peek() == "_" || peek() == "." || peek() == "-" {
            _ = advance()
        }

        let text = String(chars[start..<current])

        switch text {
        case "vgraph": addToken(.vgraph)
        case "vview": addToken(.vview)
        case "vnotation": addToken(.vnotation)
        case "metagraph": addToken(.metagraph)
        case "metadescription": addToken(.metadescription)
        case "group": addToken(.group)
        case "folded": addToken(.folded)
        case "node": addToken(.node)
        case "edge": addToken(.edge)
        default: addToken(.identifier)
        }
    }

    private func string() {
        while peek() != "\"" && !isAtEnd() {
            if peek() == "\n" { line += 1 }

            // The escape covers whatever follows the backslash, not only a
            // quote: a label ending in `\\` would otherwise leave the closing
            // quote looking escaped, and the string would run on to the next one.
            if peek() == "\\" {
                _ = advance()  // consume backslash
                if !isAtEnd() {
                    _ = advance()  // consume whatever it escapes
                }
            } else {
                _ = advance()
            }
        }

        if isAtEnd() {
            // Unterminated string
            return
        }

        _ = advance()

        // Extract the string value (including quotes)
        let value = String(chars[start..<current])
        addToken(.label, value)
    }

    private func match(_ expected: Character) -> Bool {
        if isAtEnd() { return false }
        if chars[current] != expected { return false }

        current += 1
        return true
    }

    private func advance() -> Character {
        let char = chars[current]
        current += 1
        return char
    }

    private func peek() -> Character {
        if isAtEnd() { return "\0" }
        return chars[current]
    }

    private func peekNext() -> Character {
        if current + 1 >= chars.count { return "\0" }
        return chars[current + 1]
    }

    private func isAlpha(_ c: Character) -> Bool {
        return (c >= "a" && c <= "z") || (c >= "A" && c <= "Z")
    }

    private func isDigit(_ c: Character) -> Bool {
        return c >= "0" && c <= "9"
    }

    private func isAlphaNumeric(_ c: Character) -> Bool {
        return isAlpha(c) || isDigit(c)
    }

    private func addToken(_ type: TokenType, _ lexeme: String? = nil) {
        let text = lexeme ?? String(chars[start..<current])
        tokens.append(Token(type: type, lexeme: text, line: line, start: start, end: current))
    }

    private func isAtEnd() -> Bool {
        return current >= chars.count
    }
}
