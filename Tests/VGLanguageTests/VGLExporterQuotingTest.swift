// `VGLExporter.needsQuoting` decides whether an attribute value can be written
// bare. The only correct answer is "yes, if the lexer reads it back as a single
// identifier or number token" — everything below is a value that a blacklist of
// forbidden characters let through.

import Foundation
import Testing

@testable import VGLanguage
@testable import VGraph

private func source(tooltip: String) -> String {
    """
    vgraph g: IBIS "G" {
        node q: Question "Q" [tooltip: "\(StringEscaping.escape(tooltip))"];
    }
    """
}

private func vnotationSource(edgeAttrs: String) -> String {
    """
    vnotation Q {
        node type: A [nodeStyle: simpleRoundedText, color: "#111111"]
        edge type: rel from: A to: A [\(edgeAttrs)]
    }

    vgraph g: Q "G" {
        node x: A "X";
        node y: A "Y";
        edge x -> y;
    }
    """
}

@Suite("VGL attribute value quoting")
struct VGLExporterQuotingTest {

    @Test(
        arguments: [
            "8,4",  // a dashed borderdash — the comma ends the number
            "1.2.3",  // the lexer takes one decimal point, not two
            "8px",  // digit-led, but not a number
            "1e5",  // Double() accepts the exponent, the lexer does not
            "0x1p2",  // ditto for hex float literals
            "node",  // a keyword token, so never an .identifier
            "a(b)",  // parens are tokens of their own
            "a//b",  // would comment out the rest of the line
            "a@b",  // no token type at all
            "a b",  // whitespace — quoted before the fix too, kept as a guard
            #"say "hi""#,  // the escape has to survive the round trip, not grow
            #"C:\path"#,
        ])
    func awkwardValuesSurviveExport(_ value: String) throws {
        let graph = try VGraphParser(logger: NoOpLogger()).parse(source: source(tooltip: value))
        let exported = try VGLExporter().export(graph: graph)

        let reparsed = try VGraphParser(logger: NoOpLogger()).parse(source: exported)
        let tooltip: String = try reparsed.get(node: Node(string: "q"), attribute: Attributes.Node.tooltip)
        #expect(tooltip == value)

        #expect(try VGLExporter().export(graph: reparsed) == exported)
    }

    /// The values that may still be written bare — quoting everything would be a
    /// correct but noisy fix, and VGL is meant to be read.
    @Test(arguments: ["solid", "snake_case", "dotted.name", "kebab-case", "_leading", "42", "-7", "3.5"])
    func plainValuesStayUnquoted(_ value: String) throws {
        let graph = try VGraphParser(logger: NoOpLogger()).parse(source: source(tooltip: value))
        let exported = try VGLExporter().export(graph: graph)

        #expect(exported.contains("tooltip: \(value)"))
    }

    @Test(
        arguments: [
            ("arrowHead", "8,4"), ("arrowTail", "8,4"), ("dir", "a b"), ("len", "1.2.3"),
            ("labelangle", "8,4"), ("labeldistance", "8,4"),
            ("color", "#cc3333"),  // carried its own quotes before quoting moved to the join
            ("headLabel", "a b"), ("tailLabel", "a b"),
        ])
    func vnotationEdgeTypeValuesAreQuotedExactlyOnce(_ key: String, _ value: String) throws {
        let graph = try VGraphParser(logger: NoOpLogger()).parse(source: vnotationSource(edgeAttrs: "\(key): \"\(value)\""))
        let exported = try VGLExporter().export(graph: graph)

        #expect(exported.contains("\(key): \"\(value)\""))

        let reparsed = try VGraphParser(logger: NoOpLogger()).parse(source: exported)
        #expect(try VGLExporter().export(graph: reparsed) == exported)
    }

    @Test(arguments: [("style", "dashed"), ("constraint", "false"), ("penwidth", "2.5")])
    func vnotationEdgeTypeValuesThatNeedNoQuotesKeepNone(_ key: String, _ value: String) throws {
        let graph = try VGraphParser(logger: NoOpLogger()).parse(source: vnotationSource(edgeAttrs: "\(key): \(value)"))
        let exported = try VGLExporter().export(graph: graph)

        #expect(exported.contains("\(key): \(value)"))
    }
}
