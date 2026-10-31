import Testing
import VGLanguage
import VGraph

@testable import App

/// Folding moves an edge end onto the folded node; a type that holds the new pair
/// keeps the edge (ADR-0032).
struct GainedPairFoldingTest {
    /// The folded Container is a detail of the System `uses` is declared for, so
    /// Person → Container is a gained pair of `uses`.
    @Test("Given an edge to a Component in a folded Container, when folded, then the edge keeps its own type")
    func anEdgeOntoAFoldedDetailedNodeKeepsItsType() throws {
        let s = try makeTestSession(
            vgl: """
                vnotation Arch {
                  node type: Person [nodeStyle: roundedBox]
                  node type: System [nodeStyle: roundedBox, detailedBy: (Container)]
                  node type: Container [nodeStyle: roundedBox, detailedBy: (Component)]
                  node type: Component [nodeStyle: roundedBox]
                  edge type: uses from: Person to: System
                }

                vgraph g: Arch "G" {
                  node customer: Person "Customer";
                  group shop: System "Shop" {
                    isfolded: false
                    group spa: Container "SPA" {
                      node cart: Component "Cart";
                    };
                  };
                  edge customer -> cart;
                }
                """)

        let folded = try applyFoldingLayoutStep(to: s.origin)

        let edge = try #require(folded.edges.first)
        #expect(edge.to == Node(string: "spa"))
        #expect(try folded.edgeType(for: edge).id.id == "uses")
    }
}
