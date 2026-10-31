// The grammar says `quoted_string ::= "\"" ([^\"\\] | "\\" .)* "\""`, so a
// quote or a backslash inside a label reaches the graph as itself. The lexer
// scans the escape pairs and the parser has to undo them; `StringEscaping`
// owns both directions so the two cannot drift.

import Testing

@testable import VGLanguage
@testable import VGraph

@Suite("Escaped characters in quoted strings")
struct StringEscapeRoundTripTest {

    private func parse(_ source: String) throws -> VGraph {
        try VGraphParser(logger: NoOpLogger()).parse(source: source)
    }

    private func label(of node: String, in graph: VGraph) throws -> String {
        try graph.get(node: Node(string: node), attribute: Attributes.Node.label)
    }

    // MARK: - The lexer

    @Test("A string ending in an escaped backslash is terminated, not run on")
    func trailingEscapedBackslash() {
        let tokens = Lexer(source: #"node q: Question "a\\" [fontsize: 16]"#).scanTokens()

        let labels = tokens.filter { $0.type == .label }.map { $0.lexeme }
        #expect(labels == [#""a\\""#])
        // The statement continues past the string rather than being swallowed by it.
        #expect(tokens.contains { $0.type == .leftBracket })
    }

    // MARK: - The parser

    @Test("A label unescapes to the characters it stands for")
    func labelIsUnescaped() throws {
        let graph = try parse(
            """
            vgraph t: IBIS "T" {
                node q: Question "he said \\"hi\\" to me";
            }
            """)

        #expect(try label(of: "q", in: graph) == #"he said "hi" to me"#)
    }

    @Test("A backslash in a label survives as one backslash")
    func backslashIsUnescaped() throws {
        let graph = try parse(
            """
            vgraph t: IBIS "T" {
                node q: Question "C:\\\\Users\\\\kkn";
            }
            """)

        #expect(try label(of: "q", in: graph) == #"C:\Users\kkn"#)
    }

    @Test("An attribute value unescapes the same way a label does")
    func attributeValueIsUnescaped() throws {
        let graph = try parse(
            """
            vgraph t: IBIS "T" {
                node q: Question "Q" [tooltip: "see \\"section 3.5.2\\""];
            }
            """)

        let tooltip: String = try graph.get(node: Node(string: "q"), attribute: Attributes.Node.tooltip)
        #expect(tooltip == #"see "section 3.5.2""#)
    }

    // MARK: - The round trip

    @Test(
        arguments: [
            #"he said "hi" to me"#,
            #"C:\Users\kkn"#,
            #"a "quote" and a \backslash\"#,
            #"\"#,
            #"""#,
        ])
    func exportingAndReparsingIsAFixedPoint(_ text: String) throws {
        let source = """
            vgraph t: IBIS "T" {
                node q: Question "\(StringEscaping.escape(text))";
            }
            """

        let once = try VGLExporter().export(graph: try parse(source))
        let twice = try VGLExporter().export(graph: try parse(once))

        // Backslashes multiplied once per cycle while the parser left them in.
        #expect(once == twice)
        #expect(try label(of: "q", in: try parse(once)) == text)
    }
}
