import Testing

@testable import VGraph

/// A notation is data: its types and the values on them. VGraph decides which
/// layer that data goes into (ADR-0030).
@Suite("Notation content")
struct NotationContentTests {
    let question = ItemKey(.nodeType, Notations.Ibis.NodeTypes.question.description)

    func blank() throws(VError) -> VGraph { try VGraph().defineStandardAttributes() }

    @Test
    func aNotationsContentNeedsNoGraph() {
        let content = Notations.Ibis.content
        #expect(content.nodeTypes == Notations.Ibis.NodeTypes.all)
        #expect(content.edgeTypes == Notations.Ibis.EdgeTypes.all)
        let fontsize = content.values.first { $0.key == question }?.attributes.first {
            $0.id == Attributes.Node.fontsize.id
        }
        #expect(fontsize?.stringValue == "13.0")
    }

    @Test
    func placedContentLandsInTheLayerItIsPlacedIn() throws(VError) {
        let graph = try blank().placing(Notations.Ibis.content, in: .builtin)
        #expect(graph.has(nodeType: Notations.Ibis.NodeTypes.question))
        #expect(try graph.attributes(in: .builtin, of: question)[Attributes.Node.fontsize.id] == "13.0")
        #expect(try graph.attributes(in: .vnotation, of: question).isEmpty)
    }

    @Test(arguments: NotationRegistry.entries.map { $0.id })
    func aNotationLeavesTheModelAlone(_ notation: String) throws(VError) {
        let graph = try blank().placing(NotationRegistry.entry(for: notation)!.content, in: .builtin)
        #expect(graph.ads.keys(in: .model).isEmpty, "\(graph.ads.keys(in: .model))")
    }

    @Test
    func aNotationsDiagramValuesAreInItsLayer() throws(VError) {
        let graph = try blank().placing(Notations.CurrentRealityTree.content, in: .builtin)
        #expect(
            try graph.attributes(in: .builtin, of: .root)[Attributes.Group.layoutDirection.id]
                == LayoutDirection.bottomToTop.asString)
    }

    @Test
    func anExtensionsEdgeTypesFollowTheNodeTypesItIsGiven() {
        let content = Notations.Annotation.edgeContent(given: [Notations.Ibis.NodeTypes.question])
        #expect(content.edgeTypes.map { $0.id.description }.sorted() == ["annotates__Question", "warns__Question"])
    }

    @Test
    func anExtensionPlacedInTheBuiltInLayerStaysThere() throws(VError) {
        let graph = try blank().placing(Notations.Annotation.nodeContent, in: .builtin)
        let annotation = ItemKey(.nodeType, Notations.Annotation.annotation.description)
        #expect(try !graph.attributes(in: .builtin, of: annotation).isEmpty)
        #expect(try graph.attributes(in: .vnotation, of: annotation).isEmpty)
    }

    @Test
    func placedValuesArePrunedLikeWrites() throws(VError) {
        let circle = NodeType(rawValue: "Circle")
        let base = NotationContent(nodeTypes: [circle], values: [.nodeType(circle, [Attributes.Node.fontsize(13)])])
        let repeated = NotationContent(values: [.nodeType(circle, [Attributes.Node.fontsize(13)])])
        let graph = try blank().placing(base, in: .builtin).placing(repeated, in: .vnotation)
        #expect(try graph.attributes(in: .vnotation, of: ItemKey(.nodeType, "Circle")).isEmpty)
    }

    @Test
    func aLayerThatDoesNotAdmitAValueRefusesItsPlacement() throws(VError) {
        let circle = NodeType(rawValue: "Circle")
        let content = NotationContent(nodeTypes: [circle], values: [.nodeType(circle, [Attributes.Node.fontsize(13)])])
        #expect(throws: VError.self) { try blank().placing(content, in: .model) }
    }

    @Test
    func laterValuesForTheSameTypeWin() throws(VError) {
        let circle = NodeType(rawValue: "Circle")
        let content = NotationContent(
            nodeTypes: [circle],
            values: [.nodeType(circle, [Attributes.Node.fontsize(13)]), .nodeType(circle, [Attributes.Node.fontsize(9)])])
        let graph = try blank().placing(content, in: .builtin)
        #expect(try graph.attributes(in: .builtin, of: ItemKey(.nodeType, "Circle"))[Attributes.Node.fontsize.id] == "9.0")
    }
}
