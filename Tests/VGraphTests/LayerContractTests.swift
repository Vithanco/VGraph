import Testing

@testable import VGLanguage
@testable import VGraph

/// What views and selector rules will build on.
@Suite("Layer contracts")
struct LayerContractTests {
    private func parse(_ source: String) throws -> VGraph {
        try VGraphParser(logger: NoOpLogger()).parse(source: source)
    }

    /// Judging code has no way to receive a view.
    @Test("Given a graph with a view, when it is judged, then the view changes nothing")
    func judgingNeverSeesAView() throws {
        let graph = try parse(
            #"vgraph g: IBIS "G" { node q: Question "Q"; node a: Answer "A"; node x: Nonsense "X"; edge q -> a; }"#)
        let view = AttributeLayer("view")
        let withView = graph.updatedSelfWith(
            ads: try graph.ads.addLayer(view, parent: .model, admission: .view)
                .set(Attributes.Node.backgroundColor.attribute(fromString: "#ff0000"), for: ItemKey(.node, "q"), in: view, chains: graph)
                .set(Attributes.Node.fontsize.attribute(40), for: ItemKey(.nodeType, "Answer"), in: view, chains: graph))

        let judged = Notations.analyzeQuality(graph: graph)
        #expect(!judged.messages.isEmpty)
        #expect(Notations.analyzeQuality(graph: withView).messages == judged.messages)
        for node in graph.nodes {
            #expect(try withView.getAttributes(node: node) == graph.getAttributes(node: node), "\(node)")
        }
    }

    /// A view may change only presentation, so every attribute's category is a
    /// decision. Adding an attribute fails here until it is made: list it as
    /// presentation or display in `AttributeCategories`, or as content below.
    @Test("Given every attribute VGraph defines, then each content attribute is one decided on")
    func everyContentAttributeIsDecided() {
        let content: Set<String> = [
            "edge.comment", "edge.headlabel", "edge.inDegreeMax", "edge.inDegreeMin", "edge.label", "edge.menutitle",
            "edge.outDegreeMax", "edge.outDegreeMin", "edge.samePairMax", "edge.samePairMin", "edge.taillabel",
            "edge.trailingComment", "edge.url", "graph.diagramLogic", "group.comment", "group.id", "group.label",
            "group.trailingComment", "group.url", "node.category", "node.comment", "node.label", "node.position",
            "node.tooltip", "node.totalInDegreeMax", "node.totalInDegreeMin", "node.totalOutDegreeMax",
            "node.totalOutDegreeMin", "node.trailingComment", "node.url", "vithanco.node.isJunctor",
        ]
        let actual = Set(VGraph().attributeDefinitions.values.filter { $0.category == .content }.map { $0.id.description })
        #expect(actual.subtracting(content).isEmpty, "Undecided, so content by default: \(actual.subtracting(content).sorted())")
        #expect(content.subtracting(actual).isEmpty, "No longer content: \(content.subtracting(actual).sorted())")
    }

    /// ADR-0030: every notation has the display types, and may restyle them.
    @Test("Given a vnotation value on the folded-group type, when a group folds, then the stand-in wears it")
    func aNotationRestylesADisplayType() throws {
        let graph = try parse(
            #"vgraph g: IBIS "G" { folded group box "Box" { node q: Question "Q"; }; node a: Answer "A"; }"#)
        let restyled = try graph.placing(
            NotationContent(values: [.nodeType(Notations.FoldGroups.NodeTypes.foldedGroup, [Attributes.Node.fontsize(20)])]),
            in: .vnotation)
        let folded = try applyFoldingLayoutStep(to: restyled)
        let standIn = Node(Group(rawValue: "box"))
        #expect(try folded.get(node: standIn, attribute: Attributes.Node.fontsize) == 20)
    }
}
