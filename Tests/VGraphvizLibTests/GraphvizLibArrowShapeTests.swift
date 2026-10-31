// Specifies that GraphvizLibLayoutEngine honors the edge's `arrowhead` and
// `arrowtail` attributes when synthesizing arrow shapes:
// - "dot" / "odot" → circle
// - "none"         → no arrow extracted
// - default        → triangle (polygon)
//
// Background: Concept Maps use `arrowtail=dot` with `dir=back` on the
// Concept → Relation edge to render a small dot at the concept side. The
// in-process C-library engine previously always synthesized a triangle,
// so the dot was never visible.

import Testing
import VGraph
import VGraphvizLib

@Suite("Arrow shape extraction honors arrowhead/arrowtail attributes", .serialized)
struct GraphvizLibArrowShapeTests {

    let engine = GraphvizLibLayoutEngine()

    // MARK: - Dot arrow

    @Test("Given a DOT edge with arrowtail=\"dot\" and dir=\"back\", when layout is computed, then the extracted arrowTail shape is a circle")
    func dotArrowTailProducesCircle() throws {
        let dot = """
            digraph {
                a -> b [id="e1", dir="back", arrowhead="none", arrowtail="dot"]
            }
            """

        let layout = try engine.computeLayout(dot: dot, engine: "dot")
        let edgeLayout = try #require(layout.edgeLayouts["e1"])
        let arrowTail = try #require(edgeLayout.arrowTail)

        switch arrowTail.shape {
        case .circle:
            break  // expected
        default:
            Issue.record("Expected .circle shape for arrowtail=dot, got \(arrowTail.shape)")
        }
    }

    @Test("Given a DOT edge with arrowhead=\"dot\", when layout is computed, then the extracted arrowHead shape is a circle")
    func dotArrowHeadProducesCircle() throws {
        let dot = """
            digraph {
                a -> b [id="e1", arrowhead="dot"]
            }
            """

        let layout = try engine.computeLayout(dot: dot, engine: "dot")
        let edgeLayout = try #require(layout.edgeLayouts["e1"])
        let arrowHead = try #require(edgeLayout.arrowHead)

        switch arrowHead.shape {
        case .circle:
            break
        default:
            Issue.record("Expected .circle shape for arrowhead=dot, got \(arrowHead.shape)")
        }
    }

    // MARK: - No arrow

    @Test("Given a DOT edge with arrowhead=\"none\", when layout is computed, then no arrowHead is extracted")
    func noArrowHead() throws {
        let dot = """
            digraph {
                a -> b [id="e1", arrowhead="none"]
            }
            """

        let layout = try engine.computeLayout(dot: dot, engine: "dot")
        let edgeLayout = try #require(layout.edgeLayouts["e1"])

        #expect(edgeLayout.arrowHead == nil)
    }

    @Test("Given a DOT edge with arrowtail=\"none\" and dir=\"back\", when layout is computed, then no arrowTail is extracted")
    func noArrowTail() throws {
        let dot = """
            digraph {
                a -> b [id="e1", dir="back", arrowhead="none", arrowtail="none"]
            }
            """

        let layout = try engine.computeLayout(dot: dot, engine: "dot")
        let edgeLayout = try #require(layout.edgeLayouts["e1"])

        #expect(edgeLayout.arrowTail == nil)
    }

    // MARK: - Default arrow

    @Test("Given a DOT edge with default attributes, when layout is computed, then the extracted arrowHead shape is a polygon")
    func defaultArrowHeadProducesPolygon() throws {
        let dot = """
            digraph {
                a -> b [id="e1"]
            }
            """

        let layout = try engine.computeLayout(dot: dot, engine: "dot")
        let edgeLayout = try #require(layout.edgeLayouts["e1"])
        let arrowHead = try #require(edgeLayout.arrowHead)

        switch arrowHead.shape {
        case .polygon:
            break
        default:
            Issue.record("Expected .polygon shape for default arrowhead, got \(arrowHead.shape)")
        }
    }
}
