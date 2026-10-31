// Specifies that GraphvizLibLayoutEngine keys returned edgeLayouts by
// the DOT edge's `id` attribute rather than a synthetic index. This
// eliminates an ordering-dependent contract between the layout engine
// and the code that applies layout data back to the model.

import Testing
import VGraph
import VGraphvizLib

@Suite("GraphvizLibLayoutEngine keys edgeLayouts by DOT edge id", .serialized)
struct GraphvizLibEdgeIdKeyTests {

    let engine = GraphvizLibLayoutEngine()

    @Test("Given a DOT graph whose edges carry id=\"...\" attributes, when layout is computed, then edgeLayouts is keyed by those ids")
    func edgeLayoutsKeyedByDotEdgeId() throws {
        let dot = """
            digraph {
                a -> b [id="edge-alpha"]
                b -> c [id="edge-beta"]
            }
            """

        let layout = try engine.computeLayout(dot: dot, engine: "dot")

        #expect(layout.edgeLayouts["edge-alpha"] != nil)
        #expect(layout.edgeLayouts["edge-beta"] != nil)
        #expect(layout.edgeLayouts.count == 2)
    }

    @Test(
        "Given two parallel edges between the same node pair distinguished only by id, when layout is computed, then each id appears as its own entry in edgeLayouts"
    )
    func parallelEdgesAreKeyedSeparatelyById() throws {
        let dot = """
            digraph {
                a -> b [id="first"]
                a -> b [id="second"]
            }
            """

        let layout = try engine.computeLayout(dot: dot, engine: "dot")

        #expect(layout.edgeLayouts["first"] != nil)
        #expect(layout.edgeLayouts["second"] != nil)
        #expect(layout.edgeLayouts.count == 2)
    }

    @Test(
        "Given a DOT graph whose nodes and edges are declared in an order where node-outgoing iteration differs from edge-source order, when layout is computed, then every edge is still retrievable by its id"
    )
    func nonContiguousEdgesStillKeyedById() throws {
        // a's outgoing edges are split around b->c in source order — this is
        // exactly the case that broke the old edge_N indexing.
        let dot = """
            digraph {
                a -> b [id="e1"]
                b -> c [id="e2"]
                a -> c [id="e3"]
            }
            """

        let layout = try engine.computeLayout(dot: dot, engine: "dot")

        #expect(layout.edgeLayouts["e1"] != nil)
        #expect(layout.edgeLayouts["e2"] != nil)
        #expect(layout.edgeLayouts["e3"] != nil)
    }
}
