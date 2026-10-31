// Directly covers the VGL Lexer's token stream: types, lexemes, and the
// half-open **character** start/end offsets that the syntax highlighter and
// parser depend on. These offsets are the contract the highlighter maps spans
// against, so they are asserted explicitly here (not only via the highlighter's
// "reconstruct verbatim" checks) to guard any lexer refactor — notably the
// switch from re-materialising `Array(source)` per character access (O(n²)) to
// materialising it once (O(n)), which must not shift a single offset.

import Testing

@testable import VGLanguage

@Suite struct LexerTest {

    /// Non-eof tokens as `(type, lexeme, start, end)` for compact assertions.
    private func scan(_ source: String) -> [(TokenType, String, Int, Int)] {
        Lexer(source: source).scanTokens()
            .filter { $0.type != .eof }
            .map { ($0.type, $0.lexeme, $0.start, $0.end) }
    }

    @Test func offsetsAndLexemesForATypicalStatement() {
        // "node idea: Concept" — offsets are character indices into the source.
        let tokens = scan("node idea: Concept")
        #expect(tokens.count == 4)
        #expect(tokens[0].0 == .node && tokens[0].1 == "node" && tokens[0].2 == 0 && tokens[0].3 == 4)
        #expect(tokens[1].0 == .identifier && tokens[1].1 == "idea" && tokens[1].2 == 5 && tokens[1].3 == 9)
        #expect(tokens[2].0 == .colon && tokens[2].1 == ":" && tokens[2].2 == 9 && tokens[2].3 == 10)
        #expect(tokens[3].0 == .identifier && tokens[3].1 == "Concept" && tokens[3].2 == 11 && tokens[3].3 == 18)
    }

    @Test func commentsAreSkippedButOffsetsStayAligned() {
        // The `//` comment produces no token; the token after it must keep its
        // correct absolute character offset.
        let tokens = scan("// hi\nnode")
        #expect(tokens.count == 1)
        #expect(tokens[0].0 == .node)
        #expect(tokens[0].2 == 6)  // after "// hi\n"
        #expect(tokens[0].3 == 10)
    }

    @Test func arrowStringAndNumberOffsets() {
        let tokens = scan("a -> \"x\" 12.5")
        #expect(tokens.count == 4)
        #expect(tokens[0].0 == .identifier && tokens[0].1 == "a")
        #expect(tokens[1].0 == .arrow && tokens[1].1 == "->" && tokens[1].2 == 2 && tokens[1].3 == 4)
        #expect(tokens[2].0 == .label && tokens[2].1 == "\"x\"" && tokens[2].2 == 5 && tokens[2].3 == 8)
        #expect(tokens[3].0 == .number && tokens[3].1 == "12.5" && tokens[3].2 == 9 && tokens[3].3 == 13)
    }

    @Test func multiByteCharactersCountAsSingleCharacterOffsets() {
        // A label containing a multi-byte grapheme must not desync subsequent
        // offsets: `start`/`end` are character indices, so the string spans
        // exactly its character count and the following token continues cleanly.
        let source = "\"é☃\" node"
        let tokens = scan(source)
        #expect(tokens.count == 2)
        #expect(tokens[0].0 == .label && tokens[0].1 == "\"é☃\"")
        #expect(tokens[0].2 == 0 && tokens[0].3 == 4)  // 4 characters incl. quotes
        #expect(tokens[1].0 == .node && tokens[1].2 == 5 && tokens[1].3 == 9)
    }

    @Test func keywordsAreClassified() {
        let tokens = scan("vgraph vnotation metagraph metadescription group folded node edge")
        let types = tokens.map { $0.0 }
        #expect(
            types == [
                .vgraph, .vnotation, .metagraph, .metadescription, .group, .folded, .node, .edge,
            ])
    }
}
