import Testing

@testable import VGLanguage
@testable import VGraph

private func parse(_ source: String) throws -> VGraph {
    try VGraphParser(logger: NoOpLogger()).parse(source: source)
}

/// `"A>h", "h>C"` is A → h → C, every node a Stock labelled with its id.
private func model(_ links: [String], group: (declaration: String, members: [String])? = nil) -> String {
    let names = Set(links.flatMap { $0.split(separator: ">").map(String.init) }).sorted()
    let inGroup = Set(group?.members ?? [])
    func declaration(_ name: String) -> String { "node \(name): Stock \"\(name)\";" }
    let nodes = names.filter { !inGroup.contains($0) }.map(declaration).joined(separator: "\n")
    let groups =
        group.map { g in
            "\(g.declaration) {\n" + g.members.map(declaration).joined(separator: "\n") + "\n}"
        } ?? ""
    let edges = links.map { link -> String in
        let ends = link.split(separator: ">").map(String.init)
        return "edge \(ends[0]) -> \(ends[1]): same;"
    }.joined(separator: "\n")
    return "vgraph m: CLD \"M\" {\n\(nodes)\n\(groups)\n\(edges)\n}\n"
}

private func displayed(
    _ links: [String], hiding hidden: [String] = [], header: String = "",
    group: (declaration: String, members: [String])? = nil, rule: String? = nil
) throws -> VGraph {
    let selector = rule ?? (hidden.isEmpty ? "exclude node nothere;" : "exclude node \(hidden.joined(separator: ", "));")
    let source = model(links, group: group) + "\nvview v \(header) {\n \(selector)\n}\n"
    return try parse(source).displaying(view: "v")
}

private func derived(_ graph: VGraph) -> [String] {
    graph.edges.filter { (try? graph.edgeType(for: $0))?.isDerived == true }
        .map { "\($0.from.id)>\($0.to.id)" }.sorted()
}

private func derivedEdge(_ graph: VGraph, _ from: String, _ to: String) throws -> Edge {
    try #require(graph.edges.first { $0.from.id == from && $0.to.id == to && (try? graph.edgeType(for: $0))?.isDerived == true })
}

@Suite("Derived edges: which ones a view draws")
struct DerivedEdgeSelectionTests {

    @Test("Given A → h → C, when the view hides h, then one derived edge A → C is shown")
    func oneHidden() throws {
        #expect(derived(try displayed(["A>h", "h>C"], hiding: ["h"])) == ["A>C"])
    }

    @Test("Given A → h₁ → h₂ → C, when it hides both, then one derived edge A → C is shown")
    func chain() throws {
        #expect(derived(try displayed(["A>h1", "h1>h2", "h2>C"], hiding: ["h1", "h2"])) == ["A>C"])
    }

    @Test("Given A → C and A → h → C, when it hides h, then no derived edge is shown")
    func realEdgeCovers() throws {
        #expect(derived(try displayed(["A>C", "A>h", "h>C"], hiding: ["h"])).isEmpty)
    }

    @Test("Given C → A and A → h → C, when it hides h, then a derived A → C is shown beside the real C → A")
    func realEdgeTheOtherWay() throws {
        let graph = try displayed(["C>A", "A>h", "h>C"], hiding: ["h"])
        #expect(derived(graph) == ["A>C"])
        #expect(graph.edges.count == 2)
    }

    @Test("Given A → h → B and A → h → C, when it hides h, then derived A → B and A → C are shown")
    func twoTargets() throws {
        #expect(derived(try displayed(["A>h", "h>B", "h>C"], hiding: ["h"])) == ["A>B", "A>C"])
    }

    @Test("Given A → h₁ → C and A → h₂ → C, when it hides both, then exactly one derived A → C is shown")
    func onePerPair() throws {
        #expect(derived(try displayed(["A>h1", "h1>C", "A>h2", "h2>C"], hiding: ["h1", "h2"])) == ["A>C"])
    }

    @Test("Given A → h → A, when it hides h, then a derived self-loop on A is shown")
    func selfLoop() throws {
        #expect(derived(try displayed(["A>h", "h>A"], hiding: ["h"])) == ["A>A"])
    }

    @Test("Given A → A and A → h → A, when it hides h, then no derived edge is shown")
    func realSelfLoopCovers() throws {
        #expect(derived(try displayed(["A>A", "A>h", "h>A"], hiding: ["h"])).isEmpty)
    }

    @Test("Given A → B → C, when the view hides nothing, then no derived edge is shown")
    func nothingHidden() throws {
        #expect(derived(try displayed(["A>B", "B>C"])).isEmpty)
    }

    @Test("Given A → x → B → C, when it hides x, then only a derived A → B is shown")
    func notThroughShownNodes() throws {
        #expect(derived(try displayed(["A>x", "x>B", "B>C"], hiding: ["x"])) == ["A>B"])
    }

    @Test("Given h₁ → h₂ → C, when it hides both, then no derived edge is shown")
    func bothEndsMustBeShown() throws {
        #expect(derived(try displayed(["h1>h2", "h2>C"], hiding: ["h1", "h2"])).isEmpty)
    }

    @Test("Given A → h ← C, when it hides h, then no derived edge is shown")
    func needsADirectedPath() throws {
        #expect(derived(try displayed(["A>h", "C>h"], hiding: ["h"])).isEmpty)
    }

    @Test("Given A → h → C and a view with derivedEdges: false, when it hides h, then no derived edge is shown")
    func switchedOff() throws {
        #expect(derived(try displayed(["A>h", "h>C"], hiding: ["h"], header: "[derivedEdges: false]")).isEmpty)
    }

    @Test("Given A → h → C with h in a folded group, when the view only folds, then no derived edge is shown")
    func foldingDerivesNothing() throws {
        let graph = try displayed(
            ["A>h", "h>C"], group: (declaration: "folded group g \"G\"", members: ["h"]))
        #expect(derived(graph).isEmpty)
    }

    @Test("Given A → g₁ → C with g₁ in a group, when the view hides the group, then a derived A → C is shown")
    func hiddenGroupHidesMembers() throws {
        let graph = try displayed(
            ["A>g1", "g1>C"], group: (declaration: "group grp \"G\"", members: ["g1"]), rule: "exclude group grp;")
        #expect(derived(graph) == ["A>C"])
    }

    @Test("Given A → h → C and C → h → A, when it hides h, then derived A → C and C → A are both shown")
    func bothDirections() throws {
        #expect(derived(try displayed(["A>h1", "h1>C", "C>h2", "h2>A"], hiding: ["h1", "h2"])) == ["A>C", "C>A"])
    }

    @Test("Given the same model, when no view is chosen, then no derived edge is shown")
    func defaultViewDerivesNothing() throws {
        let source = model(["A>h", "h>C"]) + "\nvview v {\n exclude node h;\n}\n"
        #expect(derived(try parse(source).displaying(view: nil)).isEmpty)
    }
}

@Suite("Derived edges: what kind of edge")
struct DerivedEdgeKindTests {

    @Test("Given links typed same and opposite, when a view hides the middle, then the derived edge has no polarity and no label")
    func noAnnotation() throws {
        let source = """
            vgraph m: CLD "M" {
              node A: Stock "A";
              node h: Stock "h";
              node C: Stock "C";
              edge A -> h: same;
              edge h -> C: opposite;
            }
            vview v {
              exclude node h;
            }
            """
        let graph = try parse(source).displaying(view: "v")
        let edge = try derivedEdge(graph, "A", "C")
        let type = try graph.edgeType(for: edge)
        #expect(type.id.id != "same" && type.id.id != "opposite")
        #expect(try graph.get(edge: edge.id, attribute: Attributes.Edge.label) == "")
    }

    @Test("Given a C4 model and a CLD model, when each hides a middle node, then each draws the same kind of derived edge")
    func everyNotation() throws {
        let c4 = """
            vgraph bank: C4 "Bank" {
              node customer: Person "Customer";
              node web: Container "Web";
              node db: Database "Storage";
              edge customer -> web;
              edge web -> db;
            }
            vview v {
              exclude node web;
            }
            """
        let c4Graph = try parse(c4).displaying(view: "v")
        let cldGraph = try displayed(["A>h", "h>C"], hiding: ["h"])
        #expect(derived(c4Graph) == ["customer>db"])
        #expect(derived(cldGraph) == ["A>C"])
    }

    @Test("Given a derived edge, its look is dotted with no label")
    func defaultLook() throws {
        let graph = try displayed(["A>h", "h>C"], hiding: ["h"])
        let edge = try derivedEdge(graph, "A", "C")
        #expect(try graph.get(edge: edge.id, attribute: Attributes.Edge.style) == .dotted)
        #expect(try graph.get(edge: edge.id, attribute: Attributes.Edge.label) == "")
    }
}
