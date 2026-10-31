// End-to-end regression test for the "short dir=back edge loses its
// dot" bug. Reproduces the arch.vgl scenario: several Concept→Relation
// edges (dir=back, arrowtail=dot) interleaved with Relation→Concept
// edges (dir=forward, arrowhead=normal). When the layout engine and
// applyLayoutData disagree on edge ordering, arrow data gets routed
// to the wrong edges and the dir-filter in `VSVGEdge` makes the
// misrouted arrows invisible.

import App
import TestSupport
import Testing
import VGraph
import VGraphvizLib

@Suite("ConceptMap arrows survive the full layout pipeline", .serialized)
struct ConceptMapArrowRoutingTests {

    @Test(
        "Given the arch.vgl ConceptMap (three dir=back edges interleaved with three dir=forward edges from mixed source nodes), when layoutGraph runs the full pipeline, then every dir=back edge has arrowTail populated and every dir=forward edge has arrowHead populated"
    )
    func conceptMapRoundTripKeepsDirBasedArrows() throws(VError) {
        let vgl = """
            vgraph arch: ConceptMap "How is the VGraph source code structured?" {

                group appLayer "Application Layer" {
                    node cli: Concept "VGraphCLI"
                    node app: EmphasizedConcept "VGraphApplication"
                }

                group parserLayer "Parser" {
                    node parser: Concept "VGraphParser"
                    node ast: Concept "ASTNode"
                }

                node r1: Relation "invokes"
                edge cli -> r1
                edge r1 -> app

                node r6: Relation "produces"
                edge parser -> r6
                edge r6 -> app

                node r7: Relation "builds"
                edge parser -> r7
                edge r7 -> ast
            }
            """

        let app = VGraphTestApp()
        let graph = try app.layoutGraph(vgl)

        // Every edge must carry its own non-empty layout.
        for edge in graph.edges {
            let layout: EdgeLayoutData = try graph.get(edge: edge.id, attribute: Attributes.Edge.layoutData)
            #expect(!layout.splinePoints.isEmpty, "edge \(edge.id) has no splinePoints")

            // The ConceptMap edge types set dir=back for Concept→Relation and
            // dir=forward for Relation→Concept. dir is inherited from edgeType.
            let dir = (try? graph.get(edge: edge.id, attribute: Attributes.Edge.dir)) ?? "forward"

            switch dir.lowercased() {
            case "back":
                #expect(layout.arrowTail != nil, "edge \(edge.id) is dir=back but has no arrowTail")
            case "forward":
                #expect(layout.arrowHead != nil, "edge \(edge.id) is dir=forward but has no arrowHead")
            default:
                break
            }
        }
    }
}
