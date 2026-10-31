import Testing

@testable import VGLanguage
@testable import VGraph

private let model = """
    vgraph m: CLD "M" {
        node A: Stock "A";
        node h: Stock "h";
        node C: Stock "C";
        edge A -> h: same;
        edge h -> C: same;
    }
    """

private func parse(_ source: String) throws -> VGraph {
    try VGraphParser(logger: NoOpLogger()).parse(source: source)
}

private func derivedEdgeCount(_ graph: VGraph, view: String) throws -> Int {
    try graph.displaying(view: view).edges.filter { (try? $0.isDerivedIn(graph)) == true }.count
}

extension Edge {
    fileprivate func isDerivedIn(_ graph: VGraph) throws -> Bool { try graph.edgeType(for: self).isDerived }
}

@Suite("derivedEdges in VGL")
struct DerivedEdgesDeclarationTests {

    @Test("Given a vview header with derivedEdges: false, when parsed, then that view turns derived edges off")
    func parsesFalse() throws {
        let graph = try parse(model + "\nvview off [derivedEdges: false] {\n exclude node h;\n}\nvview on {\n exclude node h;\n}\n")
        let shown = try graph.displaying(view: "off")
        let kept = try graph.displaying(view: "on")
        #expect(shown.edges.allSatisfy { !((try? $0.isDerivedIn(shown)) ?? false) })
        #expect(kept.edges.contains { (try? $0.isDerivedIn(kept)) ?? false })
    }

    @Test("Given a vview header with derivedEdges: maybe, when parsed, then an error names the attribute")
    func refusesNonBool() {
        #expect {
            _ = try parse(model + "\nvview v [derivedEdges: maybe] {\n exclude node h;\n}\n")
        } throws: { "\($0)".contains("derivedEdges") && !"\($0)".contains("not found") }
    }

    @Test("Given derivedEdges set on a node or group inside a view, when parsed, then it is refused as root-only")
    func refusesOnAnElement() {
        #expect {
            _ = try parse(model + "\nvview v {\n node A [derivedEdges: false];\n}\n")
        } throws: { "\($0)".contains("derivedEdges") && !"\($0)".contains("not found") }
    }

    @Test("Given a view with derivedEdges: false, when the document is exported, then the header writes it")
    func exportsFalse() throws {
        let text = try VGLExporter().export(
            graph: parse(model + "\nvview v [derivedEdges: false] {\n exclude node h;\n}\n"))
        #expect(text.lowercased().contains("derivededges: false"))
    }

    @Test("Given a view whose value equals the model's, when exported, then the file does not mention it")
    func prunesEqualValue() throws {
        let text = try VGLExporter().export(
            graph: parse(model + "\nvview v [derivedEdges: true] {\n exclude node h;\n}\n"))
        #expect(!text.contains("derivedEdges"))
    }

    @Test("Given a document with derived edges on screen, when exported, then no derived edge is written, and re-parsing gives the same document")
    func exportWritesNoDerivedEdge() throws {
        let graph = try parse(model + "\nvview v [derivedEdges: false] {\n exclude node h;\n}\n")
        _ = try graph.displaying(view: "v")
        let first = try VGLExporter().export(graph: graph)
        let second = try VGLExporter().export(graph: parse(first))
        #expect(!first.contains("derived-") && !first.contains("derived__"))
        #expect(first == second)
    }
}
