import TestSupport
import Testing

@testable import VGraph

@Suite
struct BBSNotationTests {

    @Test func testBBSLayoutDirectionIsLeftToRight() throws {
        var graph = VGraph()
        graph = try Notations.Bbs.addNotation(addTo: graph)

        let layoutDirectionString: String = try graph.get(
            graphAttribute: Attributes.Group.layoutDirection
        )
        let layoutDirection = try LayoutDirection.fromString(layoutDirectionString)
        #expect(layoutDirection == .leftToRight)
    }
}
