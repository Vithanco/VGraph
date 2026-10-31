import TestSupport
import Testing

@testable import App
@testable import VGraph

/// An unfolded detailed node's boundary is titled with its node label.
struct DetailedNodeBoundaryTitleTests {

    @Test func theBoundaryIsTitledWithTheNodeLabel() throws {
        let svg = try VGraphTestApp().renderGraph(
            """
            vgraph arch: C4 "Architecture" {
                group ibs: SoftwareSystem "Internet Banking System" {
                    isfolded: false
                    node web: Container "Web App";
                }
            }
            """
        ).svg

        #expect(svg.contains(">INTERNET BANKING SYSTEM<"))
    }
}
