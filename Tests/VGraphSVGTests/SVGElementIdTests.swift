import Testing

@testable import App
@testable import VGLanguage
@testable import VGraph
@testable import VGraphSVG

struct SVGElementIdTests {

    @Test func mintedIdsResolveBackToTheOriginGraphId() {
        #expect(SVGElementId.originId(fromDomId: SVGElementId.node("a1")) == "a1")
        #expect(SVGElementId.originId(fromDomId: SVGElementId.edge("relation_1")) == "relation_1")
        #expect(SVGElementId.originId(fromDomId: SVGElementId.group("g1")) == "g1")
    }

    @Test func onlyTheStampedPrefixIsStrippedAndOnlyOnce() {
        #expect(SVGElementId.originId(fromDomId: SVGElementId.node("node-a1")) == "node-a1")
        #expect(SVGElementId.originId(fromDomId: SVGElementId.group("edge-x")) == "edge-x")
    }

    @Test func anUnstampedIdIsNotAGraphElement() {
        #expect(SVGElementId.originId(fromDomId: "vg-editor-preview") == nil)
        #expect(SVGElementId.originId(fromDomId: "") == nil)
        #expect(SVGElementId.originId(fromDomId: "nodes-a1") == nil)
    }

    @Test func aBarePrefixIsNotAGraphElement() {
        #expect(
            SVGElementId.originId(fromDomId: "node-") == nil,
            "an empty id would reach availableCommands(forTargetId:) as if it were an element")
        #expect(SVGElementId.originId(fromDomId: "edge-") == nil)
        #expect(SVGElementId.originId(fromDomId: "group-") == nil)
    }

    @Test func eachTargetKindGetsItsOwnPrefix() {
        #expect(SVGElementId.domId(for: .node(Node(string: "a1"))) == "node-a1")
        #expect(SVGElementId.domId(for: .edge(Edge.Id(string: "relation_1"))) == "edge-relation_1")
        #expect(SVGElementId.domId(for: .group(Group(rawValue: "g1"))) == "group-g1")
    }

    @Test func targetDomIdsMatchWhatTheRendererStamps() throws {
        let svg = try renderedSVG()

        #expect(svg.contains("id=\"\(SVGElementId.domId(for: .node(Node(string: "a1"))))\""))
        #expect(svg.contains("id=\"\(SVGElementId.domId(for: .group(Group(rawValue: "g1"))))\""))
    }

    @Test func onlyAClickInTheGroupLabelCanResolveToAGroup() {
        #expect(SVGElementId.doubleClickSelector(insideGroupLabel: true) == ".vgraph-group")
        #expect(
            SVGElementId.doubleClickSelector(insideGroupLabel: false) == ".vgraph-node,.vgraph-edge",
            "a boundary covers everything inside it, so anything else must fall through")
    }

    @Test func rightClickResolvesAgainstEveryGraphElement() {
        let selector = SVGElementId.contextMenuSelector

        #expect(selector.contains(".\(SVGElementId.groupClass)"))
        #expect(selector.contains(".\(SVGElementId.nodeClass)"))
        #expect(selector.contains(".\(SVGElementId.edgeClass)"))
    }

    @Test func theRendererEmitsTheClassesTheSelectorsName() throws {
        let svg = try renderedSVG()

        #expect(svg.contains("class=\"\(SVGElementId.nodeClass)\""))
        #expect(svg.contains(SVGElementId.groupClass))
        #expect(svg.contains(SVGElementId.groupLabelClass))
    }

    private func renderedSVG() throws -> String {
        let input = """
            vgraph myGraph: IBIS "Test Graph" {
                group g1 "My Group" {
                    node a1: Answer "Answer in group";
                };
            }
            """
        let graph = try VGraphParser(logger: TestLogger()).parse(source: input)

        var layouted = graph
        for node in graph.nodes {
            layouted = try layouted.set(
                node: node, attribute: Attributes.Node.layoutedPos.attribute(VPoint(x: 50, y: 50)))
            layouted = try layouted.set(
                node: node,
                attribute: Attributes.Node.layoutedSize.attribute(VSize(width: 80, height: 40)))
        }
        // A group renders only once Graphviz has given it bounds.
        layouted = try layouted.set(
            group: Group(rawValue: "g1"),
            attribute: Attributes.Group.layoutedBounds.attribute(
                VRect(origin: VPoint(x: 0, y: 0), size: VSize(width: 200, height: 120))))

        return try VSVGRenderer(logger: TestLogger()).render(graph: layouted)
    }
}
