// Pins the exact hover rules for the shapes the renderer tests do not draw:
// a self-loop, parallel edges and a junctor chain in one graph. The rule text
// is order-sensitive, and snapshot diffs are hard to read, so any change to
// how neighbourhoods are gathered shows up here first.

import Testing

@testable import VGLanguage
@testable import VGraph
@testable import VGraphSVG

@Suite("SVGHoverStyles")
struct SVGHoverStylesTests {

    private func rules(_ source: String) throws -> String {
        let graph = try VGraphParser(logger: TestLogger()).parse(source: source)
        return SVGHoverStyles.rules(graph: graph)
    }

    /// One line per hover scope: the hovered id, then every id it lights up, in
    /// emitted order. Read off the glow rule, which names each target once.
    private func highlights(_ source: String) throws -> [String] {
        try rules(source).split(separator: "\n")
            .filter { $0.contains("drop-shadow") }
            .map { line in
                let selectors = line.prefix { $0 != "{" }.split(separator: ",")
                let hovered = selectors[0].split(separator: "#")[1].prefix { $0 != ":" }
                let lit = selectors.map { $0.split(separator: "#").last ?? "" }
                return "\(hovered): " + lit.joined(separator: " ")
            }
    }

    @Test func graphWithoutEdgesHasNoRules() throws {
        let source = """
            vgraph cld: CLD "Lonely" {
                node a: Stock "A"
            }
            """
        #expect(try rules(source) == "")
    }

    @Test func selfLoopAndParallelEdgesPinned() throws {
        let source = """
            vgraph cld: CLD "Edge shapes" {
                node a: Stock "A"
                node b: Stock "B"
                edge a -> b: same
                edge a -> b: opposite
                edge b -> b: same
            }
            """
        #expect(
            try highlights(source) == [
                "node-a: edge-100002 edge-100003 node-b",
                "node-b: edge-100002 edge-100003 edge-100004 node-a",
                "edge-100002: node-a node-b",
                "edge-100003: node-a node-b",
                "edge-100004: node-b",
            ])
    }

    @Test func junctorChainPinned() throws {
        let source = """
            vgraph crt: CRT "Junctor chain" {
                node a: Changeable "Cause A"
                node c: Changeable "Cause C"
                node j: AndJunctor
                node b: UndesirableEffect "Effect B"
                edge a -> j
                edge c -> j
                edge j -> b
            }
            """
        #expect(
            try highlights(source) == [
                "node-a: edge-100002 edge-100003 edge-100004 node-j node-c node-b",
                "node-c: edge-100003 edge-100002 edge-100004 node-j node-a node-b",
                "node-j: edge-100002 edge-100003 edge-100004 node-a node-c node-b",
                "node-b: edge-100004 edge-100002 edge-100003 node-j node-a node-c",
                "edge-100002: edge-100002 edge-100003 edge-100004 node-a node-j node-c node-b",
                "edge-100003: edge-100002 edge-100003 edge-100004 node-c node-j node-a node-b",
                "edge-100004: edge-100002 edge-100003 edge-100004 node-j node-a node-c node-b",
            ])
    }
}
