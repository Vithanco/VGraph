////  Behavioural rules of the pre-layout steps that were previously only
////  asserted in code comments: the empty-label guard in `applyTextWrapping`
////  and the circle → square rule in `calculateNodeDimensions`.
////

import Testing

@testable import App
@testable import VGraph

struct LayoutStepTests {

    /// Builds a one-node graph with the given label and node style. The shape is
    /// derived from the style by the pipeline (`extractNodeShape`), as in production —
    /// the tests never hand-set the shape attribute.
    private func makeGraph(label: String, nodeStyle: NodeStyle = .bareText) throws -> (VGraph, Node) {
        var graph = VGraph()
        let nodeType = NodeType(rawValue: "TestNode")
        graph = try graph.adding(nodeType: nodeType)
        graph = try graph.setting(nodeType: nodeType, attribute: Attributes.Node.nodeStyle.attribute(nodeStyle))

        let node = Node(rawValue: "n")
        graph = try graph.adding(node: node, type: nodeType)
        graph = try graph.setting(node: node, attribute: Attributes.Node.label.attribute(label))
        graph = try graph.setting(node: node, attribute: Attributes.Node.fontsize.attribute(14))
        return (graph, node)
    }

    /// Runs the sizing steps in pipeline order and returns the node's computed size.
    private func dimensions(of node: Node, in graph: VGraph) throws -> VSize {
        var result = try DisplayPipeline.assembleNodeStyles(graph)
        result = try DisplayPipeline.applyTextWrapping(result)
        result = try DisplayPipeline.calculateNodeTextDimensions(result)
        result = try DisplayPipeline.extractNodeShape(result)
        result = try DisplayPipeline.calculateNodeDimensions(result)
        return try result.get(node: node, attribute: Attributes.Node.layoutedSize)
    }

    // MARK: - applyTextWrapping

    @Test func emptyLabelWrapsToNoLines() throws {
        let (graph, node) = try makeGraph(label: "")

        let wrapped = try DisplayPipeline.applyTextWrapping(graph)

        let lines = try wrapped.get(node: node, attribute: Attributes.Node.wrappedText)
        #expect(lines.isEmpty)
    }

    @Test func nonEmptyLabelWrapsToAtLeastOneLine() throws {
        let (graph, node) = try makeGraph(label: "Hello")

        let wrapped = try DisplayPipeline.applyTextWrapping(graph)

        let lines = try wrapped.get(node: node, attribute: Attributes.Node.wrappedText)
        #expect(!lines.isEmpty)
    }

    // MARK: - calculateNodeDimensions

    // A single-line label that is naturally wider than tall, so a square result
    // can only come from the circle rule, not from the input shape.
    private static let wideLabel = "Hello World"

    @Test func circleStyleForcesSquareDimensions() throws {
        let (graph, node) = try makeGraph(label: Self.wideLabel, nodeStyle: .circle)

        let size = try dimensions(of: node, in: graph)
        #expect(size.width > 0)
        #expect(size.width == size.height)
    }

    @Test func boxStyleKeepsWideLabelWiderThanTall() throws {
        // The same label as a plain box stays wider than tall, confirming the square
        // result above is the circle branch and not an artefact of the input.
        let (graph, node) = try makeGraph(label: Self.wideLabel, nodeStyle: .bareText)

        let size = try dimensions(of: node, in: graph)
        #expect(size.width > size.height)
    }

    // MARK: - pipeline contract

    @Test func sizingStepWithUnmetPrerequisiteThrows() throws {
        // calculateNodeDimensions on a fresh graph — none of its prerequisites ran.
        let (graph, _) = try makeGraph(label: "x")
        #expect(
            throws: VError.pipelineContractViolated(
                step: "calculateNodeDimensions",
                missing: ["assembleNodeStyles", "calculateNodeTextDimensions", "extractNodeShape"])
        ) {
            try DisplayPipeline.calculateNodeDimensions(graph)
        }
    }
}
