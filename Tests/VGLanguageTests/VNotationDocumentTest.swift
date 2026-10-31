import Testing

@testable import App
@testable import VGLanguage
@testable import VGraph

/// A document with a `vnotation` that uses every part of the block, through
/// parse, export and reparse. No repo fixture has one.
@Suite("A vnotation document")
struct VNotationDocumentTest {
    static let source = """
        vnotation Mine extends IBIS {
        	layout: leftToRight

        	icon flame [viewBox: "0 0 24 24", path: "M12 2L4 22h16z"]

        	node type: Question [backgroundColor: "#ffeeaa"]
        	node type: Extra [nodeStyle: withCategory, backgroundColor: "#884499", category: "E"]

        	edge type: extra_raises  from: Extra  to: Question [color: "#ff0000", style: dashed]

        	qualityCheck: treeStructure
        	transform: identity
        }

        vgraph g: Mine "G" {
        	splines: ortho

        	node q: Question "Q"
        	node x: Extra "X"
        	edge x -> q
        }
        """

    private func parse(_ source: String) throws -> VGraph {
        try VGraphParser(logger: NoOpLogger()).parse(source: source)
    }

    private func roundTripped() throws -> (VGraph, VGraph) {
        let first = try parse(Self.source)
        return (first, try parse(VGLExporter().export(graph: first)))
    }

    @Test("Given a vnotation document, when exported and reparsed, then the export does not change")
    func exportIsStable() throws {
        let first = try VGLExporter().export(graph: parse(Self.source))
        let second = try VGLExporter().export(graph: parse(first))
        #expect(first == second)
    }

    @Test("Given a vnotation document, when it round-trips, then every element resolves as before")
    func elementsResolveAsBefore() throws {
        let (before, after) = try roundTripped()
        for node in before.nodes {
            #expect(try before.getAttributes(node: node) == after.getAttributes(node: node), "\(node)")
        }
        let edge = try #require(before.edges.first).id
        let edgeAfter = try #require(after.edges.first).id
        #expect(try before.getAttributes(edge: edge) == after.getAttributes(edge: edgeAfter))
        #expect(try before.getGraphAttributes() == after.getGraphAttributes())
    }

    @Test("Given a vnotation document, when it round-trips, then its types and definition are kept")
    func typesAndDefinitionAreKept() throws {
        let (before, after) = try roundTripped()
        for type in before.nodeTypes {
            #expect(before.getAllAttributes(nodeType: type) == after.getAllAttributes(nodeType: type), "\(type)")
        }
        for type in before.edgeTypes {
            #expect(before.getAllAttributes(edgeType: type.id) == after.getAllAttributes(edgeType: type.id), "\(type.id)")
        }
        #expect(before.notationDefinition == after.notationDefinition)
    }

    @Test("Given a vnotation document, when parsed, then each value is in the layer that wrote it")
    func eachValueIsInItsLayer() throws {
        let graph = try parse(Self.source)
        let question = ItemKey(.nodeType, "Question")
        #expect(try graph.attributes(in: .vnotation, of: question)[Attributes.Node.backgroundColor.id] != nil)
        #expect(try graph.attributes(in: .builtin, of: question)[Attributes.Node.backgroundColor.id] != "#ffeeaaff")
        #expect(try !graph.attributes(in: .vnotation, of: ItemKey(.nodeType, "Extra")).isEmpty)
        #expect(try graph.attributes(in: .vnotation, of: .root)[Attributes.Group.layoutDirection.id] != nil)
        #expect(try graph.attributes(in: .model, of: .root)[Attributes.Group.splines.id] == "ortho")
    }

    @Test("Given a vnotation document, when rendered, then every element is drawn")
    func itRenders() throws {
        let app = VGraphApplication(ports: NativePorts(logger: NoOpLogger()))
        let svg = try app.renderGraph(Self.source).svg
        #expect(svg.contains("node-q"))
        #expect(svg.contains("node-x"))
    }

    /// The store keeps them in a dictionary, whose order changes from process
    /// to process, so the export must not follow it.
    @Test("Given a vnotation with several diagram values, when exported, then they are in key order")
    func diagramValuesAreInKeyOrder() throws {
        let exported = try VGLExporter().export(
            graph: parse(
                """
                vnotation Mine extends IBIS {
                	splines: ortho
                	sep: "+20"
                	layout: leftToRight
                	overlap: scale
                }

                vgraph g: Mine "G" {
                	node q: Question "Q"
                }
                """))
        let block = exported.split(separator: "\n").dropFirst().prefix(4).map { String($0) }
        #expect(block == ["\tlayout: leftToRight", "\toverlap: scale", "\tsep: \"+20\"", "\tsplines: ortho"])
    }
}
