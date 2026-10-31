// Covers the VGL syntax highlighter (lexical + semantic passes) exposed on
// VGraphParser. Asserts on the produced HTML spans and on the underlying
// classification, and verifies the source is reconstructed verbatim.

import Testing

@testable import App
@testable import VGLanguage
@testable import VGraph

private let sample = """
    // a comment
    vgraph demo: ConceptMap "Title" {
      node idea: Concept "Idea";
      node bad: Nonsense "Oops";
      edge idea -> bad [color: red];
    }
    """

/// Strip all HTML tags, unescape entities — the result must equal the source.
private func stripTags(_ html: String) -> String {
    var out = ""
    var inTag = false
    for c in html {
        if c == "<" {
            inTag = true
            continue
        }
        if c == ">" {
            inTag = false
            continue
        }
        if !inTag { out.append(c) }
    }
    return
        out
        .replacingOccurrences(of: "&lt;", with: "<")
        .replacingOccurrences(of: "&gt;", with: ">")
        .replacingOccurrences(of: "&amp;", with: "&")
}

@Suite struct SyntaxHighlightTest {

    @Test func lexicalColorsKeywordsStringsCommentsNumbers() {
        let parser = VGraphParser(logger: NoOpLogger())
        let html = parser.lexicalHighlightHTML(source: sample)

        #expect(html.contains("<span class=\"vg-kw\">vgraph</span>"))
        #expect(html.contains("<span class=\"vg-kw\">node</span>"))
        #expect(html.contains("<span class=\"vg-kw\">edge</span>"))
        #expect(html.contains("<span class=\"vg-notation\">ConceptMap</span>"))
        #expect(html.contains("<span class=\"vg-str\">\"Title\"</span>"))
        #expect(html.contains("<span class=\"vg-comment\">// a comment</span>"))
        // Arrow is punctuation.
        #expect(html.contains("<span class=\"vg-punct\">-&gt;</span>"))
    }

    @Test func lexicalReconstructsSourceVerbatim() {
        let parser = VGraphParser(logger: NoOpLogger())
        let html = parser.lexicalHighlightHTML(source: sample)
        #expect(stripTags(html) == sample)
    }

    @Test func semanticClassifiesRolesAndFlagsUnknownType() {
        let parser = VGraphParser(logger: NoOpLogger())
        let html = parser.semanticHighlightHTML(source: sample)

        // Valid node type vs unknown node type.
        #expect(html.contains("<span class=\"vg-type\">Concept</span>"))
        #expect(html.contains("<span class=\"vg-error\">Nonsense</span>"))
        // Node id, attribute key, attribute value.
        #expect(html.contains("<span class=\"vg-id\">idea</span>"))
        #expect(html.contains("<span class=\"vg-attr\">color</span>"))
        #expect(html.contains("<span class=\"vg-val\">red</span>"))
        // Notation name still colored in the semantic pass.
        #expect(html.contains("<span class=\"vg-notation\">ConceptMap</span>"))
    }

    @Test func semanticHighlightsTypedGroupAsType() {
        let source = """
            vnotation Teams {
              node type: Member [nodeStyle: roundedBox]
              group type: Team
            }

            vgraph g: Teams "G" {
              group core: Team "S" {
                node ann: Member "Ann";
              };
            }
            """
        let parser = VGraphParser(logger: NoOpLogger())
        let html = parser.semanticHighlightHTML(source: source)

        // A group's type is a GroupType, not a NodeType, so it must be coloured as a
        // type — never flagged as an unknown node type (which would show red).
        #expect(html.contains("<span class=\"vg-type\">Team</span>"))
        #expect(!html.contains("<span class=\"vg-error\">Team</span>"))
    }

    @Test func semanticReconstructsSourceVerbatim() {
        let parser = VGraphParser(logger: NoOpLogger())
        let html = parser.semanticHighlightHTML(source: sample)
        #expect(stripTags(html) == sample)
    }

    @Test func semanticMarksSyntaxErrorPosition() {
        let parser = VGraphParser(logger: NoOpLogger())
        // `lea:ds` — after `node lea: ds` the parser expects a statement but hits
        // the stray colon, so it flags that token.
        let broken = "vgraph demo: ConceptMap \"D\" {\n  node lea:ds: Relation\n}"
        let html = parser.semanticHighlightHTML(source: broken)
        // The offending token is wrapped as a syntax-error span, and the source
        // is still reconstructed verbatim.
        #expect(html.contains("class=\"vg-syntax-error\""))
        #expect(stripTags(html) == broken)
    }

    @Test func semanticStillHighlightsOnSyntaxError() {
        let parser = VGraphParser(logger: NoOpLogger())
        // Even when parsing fails, keywords/notation are colored lexically.
        let broken = "vgraph demo: ConceptMap {\n  node x: "
        let html = parser.semanticHighlightHTML(source: broken)
        #expect(html.contains("<span class=\"vg-kw\">vgraph</span>"))
        #expect(html.contains("<span class=\"vg-notation\">ConceptMap</span>"))
        #expect(stripTags(html) == broken)
    }

    @Test func aViewIsHighlightedAndReconstructedVerbatim() {
        let source = sample + "\n\nvview v \"V\" {\n  folded group type: Box;\n  node idea [fontsize: 16];\n}"
        let parser = VGraphParser(logger: NoOpLogger())
        for html in [parser.lexicalHighlightHTML(source: source), parser.semanticHighlightHTML(source: source)] {
            #expect(html.contains("<span class=\"vg-kw\">vview</span>"))
            #expect(stripTags(html) == source)
        }
    }

    @Test func diagnosticsMarkInvalidEdgeWithTooltip() throws {
        // Concept -> Concept has no valid ConceptMap edge type, so the report
        // flags the edge; the overlay should wrap that edge statement.
        let src =
            "vgraph demo: ConceptMap \"D\" {\n  node idea: Concept \"Idea\";\n  node detail: Concept \"Detail\";\n  edge idea -> detail;\n}"
        let graph = try VGraphParser(logger: NoOpLogger()).parse(source: src)
        let report = Notations.analyzeQuality(graph: graph)
        let html = VGraphParser(logger: NoOpLogger()).semanticHighlightHTML(source: src, report: report)

        #expect(html.contains("class=\"vg-diag-error\""))
        #expect(html.contains("invalid edge type"))  // the tooltip text
        #expect(stripTags(html) == src)  // still verbatim
    }

    @Test func diagnosticsMarkDisconnectedNodeAsWarning() throws {
        // `lonely` has no edges → a warning targeted at that node.
        let src =
            "vgraph demo: ConceptMap \"D\" {\n  node a: Concept \"A\";\n  node b: Relation \"leads\";\n  node lonely: Concept \"Lonely\";\n  edge a -> b;\n}"
        let graph = try VGraphParser(logger: NoOpLogger()).parse(source: src)
        let report = Notations.analyzeQuality(graph: graph)
        let html = VGraphParser(logger: NoOpLogger()).semanticHighlightHTML(source: src, report: report)

        #expect(html.contains("class=\"vg-diag-warn\""))
        #expect(stripTags(html) == src)
    }

    @Test func diagnosticsGroupMultipleFindingsOnOneElementIntoOneMarker() throws {
        // `lonely` trips two warnings (disconnected + not connected to a relation).
        let src =
            "vgraph demo: ConceptMap \"D\" {\n  node a: Concept \"A\";\n  node b: Relation \"leads\";\n  node lonely: Concept \"Lonely\";\n  edge a -> b;\n}"
        let graph = try VGraphParser(logger: NoOpLogger()).parse(source: src)
        let report = Notations.analyzeQuality(graph: graph)
        let html = VGraphParser(logger: NoOpLogger()).semanticHighlightHTML(source: src, report: report)

        // Exactly one marker, whose single tooltip lists both findings.
        #expect(html.components(separatedBy: "class=\"vg-diag-warn\"").count - 1 == 1)
        #expect(html.contains("disconnected (no edges)"))
        #expect(html.contains("not connected to any relation"))
    }

    @Test func graphGlobalFindingsProduceNoMarker() throws {
        // A clean, well-connected small map: any remaining findings (e.g. the
        // low concept-count warning) are `.graph`-targeted and must NOT mark.
        let src =
            "vgraph demo: ConceptMap \"D\" {\n  node a: Concept \"A\";\n  node r: Relation \"drives\";\n  node b: Concept \"B\";\n  edge a -> r;\n  edge r -> b;\n}"
        let graph = try VGraphParser(logger: NoOpLogger()).parse(source: src)
        let report = Notations.analyzeQuality(graph: graph)
        let html = VGraphParser(logger: NoOpLogger()).semanticHighlightHTML(source: src, report: report)

        // There are warnings/infos in the report, but they are whole-graph.
        #expect(!html.contains("vg-diag-error"))
        #expect(!html.contains("vg-diag-warn"))
        #expect(stripTags(html) == src)
    }

    @Test func diagnosticsCoverIBISNotationTargets() throws {
        let src =
            "vgraph d: IBIS \"T\" {\n  node q: Question \"Q?\";\n  node a1: Answer \"A1\";\n  node a2: Answer \"A2\";\n  edge q -> a1;\n  edge q -> a2;\n  edge a1 -> a2;\n}"
        let graph = try VGraphParser(logger: NoOpLogger()).parse(source: src)
        let report = Notations.analyzeQuality(graph: graph)
        let html = VGraphParser(logger: NoOpLogger()).semanticHighlightHTML(source: src, report: report)

        #expect(html.contains("parent nodes"))
        #expect(stripTags(html) == src)
    }

    @Test func htmlEscapesAngleBracketsInStrings() {
        let parser = VGraphParser(logger: NoOpLogger())
        let src = "vgraph d: ConceptMap \"a <b> & c\" { node n: Concept; }"
        let html = parser.lexicalHighlightHTML(source: src)
        #expect(html.contains("&lt;b&gt;"))
        #expect(html.contains("&amp;"))
        #expect(stripTags(html) == src)
    }
}

/// The third place a missing icon has to show, after the diagram and the
/// quality report (ADR-0022).
@Suite struct IconNameHighlightTest {

    private static let flame = "M12 2c0.5,3.5 -4,5 -4,9 a4,4 0 0 0 8,0 c0,-2 -2,-4 -4,-7z"

    private func source(icons: String, iconName: String) -> String {
        """
        vnotation RiskMap {
        \(icons)
            node type: Risk [nodeStyle: iconWithText, backgroundColor: "#cc3333", icon: "\(iconName)"]
            edge type: rel from: Risk to: Risk
        }

        vgraph rm: RiskMap "Risks" {
            node r1: Risk "Overrun";
        }
        """
    }

    @Test func aNameNobodyHasIsColouredAsAnError() {
        let html = VGraphParser(logger: NoOpLogger())
            .semanticHighlightHTML(source: source(icons: "", iconName: "no.such.mark"))

        #expect(html.contains("<span class=\"vg-error\">\"no.such.mark\"</span>"))
    }

    @Test func aBuiltInNameIsNotAnError() {
        let html = VGraphParser(logger: NoOpLogger())
            .semanticHighlightHTML(source: source(icons: "", iconName: "and"))

        #expect(!html.contains("<span class=\"vg-error\">\"and\"</span>"))
    }

    @Test func aNameTheNotationDeclaresIsNotAnError() {
        let declaration = "    icon flame [viewBox: \"0 0 24 24\", path: \"\(Self.flame)\"]"
        let html = VGraphParser(logger: NoOpLogger())
            .semanticHighlightHTML(source: source(icons: declaration, iconName: "flame"))

        #expect(!html.contains("<span class=\"vg-error\">\"flame\"</span>"))
    }

    /// The highlighter reconstructs the source verbatim; a new span must not
    /// swallow the quotes around the name.
    @Test func theSourceSurvivesTheNewSpan() {
        let src = source(icons: "", iconName: "no.such.mark")
        let html = VGraphParser(logger: NoOpLogger()).semanticHighlightHTML(source: src)

        #expect(stripTags(html) == src)
    }
}
