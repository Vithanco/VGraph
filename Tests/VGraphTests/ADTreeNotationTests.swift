import TestSupport
import Testing

@testable import VGraph

@Suite
struct ADTreeNotationTests {

    @Test func testADTreeLayoutDirectionIsBottomToTop() throws {
        var graph = VGraph()
        graph = try Notations.ADTree.addNotation(to: graph)

        let layoutDirectionString: String = try graph.get(
            graphAttribute: Attributes.Group.layoutDirection
        )
        let layoutDirection = try LayoutDirection.fromString(layoutDirectionString)
        #expect(layoutDirection == .bottomToTop)
    }

    @Test func testCountermeasureEdgesAreDotted() throws {
        var graph = VGraph()
        graph = try Notations.ADTree.addNotation(to: graph)

        let defenseCountersStyle: Attributes.Edge.StyleType = try graph.get(
            edgeType: Notations.ADTree.EdgeTypes.defenseCountersAttack.id,
            attribute: Attributes.Edge.style
        )
        #expect(defenseCountersStyle == .dotted)

        let attackCountersStyle: Attributes.Edge.StyleType = try graph.get(
            edgeType: Notations.ADTree.EdgeTypes.attackCountersDefense.id,
            attribute: Attributes.Edge.style
        )
        #expect(attackCountersStyle == .dotted)
    }
}
