import Testing

@testable import VGraph

@Suite
struct GroupStyleTests {

    let group1 = Group(rawValue: "group1")

    private func baseGraph() throws(VError) -> VGraph {
        return try VGraph().defineStandardAttributes()
    }

    @Test("Given a group assigned a group style, when its style is read back, then both the folded box and the boundary appearance are available")
    func groupCarriesFoldedAndBoundaryAppearance() throws(VError) {
        // A color-free folded face keeps the folded comparison structural; the boundary
        // now carries semantic colours, which the attribute store re-serialises to
        // literals (id dropped, dark hex recomputed), so compare it canonically.
        let folded = NodeStyleLayout.empty
        let boundary = BoundaryChrome(cornerRadius: 12, borderDash: "4,2")
        let style = GroupStyle(folded: folded, unfolded: boundary)

        var graph = try baseGraph().add(group: group1)
        graph = try graph.set(group: group1, attribute: Attributes.Group.groupStyle.attribute(style))

        let readBack = try graph.get(group: group1, attribute: Attributes.Group.groupStyle)
        #expect(readBack.asString == style.asString)
        #expect(readBack.folded == folded)
        #expect(readBack.unfolded.asString == boundary.asString)
    }

    @Test("Given a group with no assigned style, when its style is requested, then the default group style is returned")
    func unstyledGroupResolvesToDefault() throws(VError) {
        let graph = try baseGraph().add(group: group1)

        let readBack = try graph.get(group: group1, attribute: Attributes.Group.groupStyle)
        #expect(readBack.asString == GroupStyle.default.asString)
    }
}
