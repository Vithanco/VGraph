import Testing

@testable import VGraph

@Suite
struct GroupStyleTests {

    let group1 = Group(rawValue: "group1")

    private func baseGraph() throws(VError) -> VGraph {
        return VGraph()
    }

    @Test("Given a group assigned a group style, when its style is read back, then both the folded box and the frame are available")
    func groupCarriesFoldedBoxAndFrame() throws(VError) {
        // A color-free folded face keeps the folded comparison structural; the frame
        // now carries semantic colours, which the attribute store re-serialises to
        // literals (id dropped, dark hex recomputed), so compare it canonically.
        let folded = NodeStyleLayout.empty
        let frame = GroupFrame(cornerRadius: 12, borderDash: "4,2")
        let style = GroupStyle(folded: folded, unfolded: frame)

        var graph = try baseGraph().adding(group: group1)
        graph = try graph.setting(group: group1, attribute: Attributes.Group.groupStyle(style))

        let readBack = try graph.get(group: group1, attribute: Attributes.Group.groupStyle)
        #expect(readBack.asString == style.asString)
        #expect(readBack.folded == folded)
        #expect(readBack.unfolded.asString == frame.asString)
    }

    @Test("Given a group with no assigned style, when its style is read, then it is the default group style, which round-trips")
    func anUnstyledGroupReadsTheDefault() throws(VError) {
        let graph = try baseGraph().adding(group: group1)
        let readBack = try graph.get(group: group1, attribute: Attributes.Group.groupStyle)
        #expect(readBack.asString == GroupStyle.default.asString)
        #expect(try GroupStyle.fromString(readBack.asString).asString == readBack.asString)
    }

    @Test("Given a group style whose folded box lacks a closing brace, when it is read, then reading fails")
    func aMissingBraceIsAnError() {
        #expect(throws: VError.parsingError("NodeStyleLayout: expected '}' in 'o{empty|empty'")) {
            try GroupStyle.fromString(withFolded("o{empty|empty"))
        }
    }

    @Test("Given a group style whose folded overlay lacks its separator, when it is read, then reading fails")
    func aMissingSeparatorIsAnError() {
        #expect(throws: VError.parsingError("NodeStyleLayout: expected '|' in 'o{empty empty}'")) {
            try GroupStyle.fromString(withFolded("o{empty empty}"))
        }
    }

    private func withFolded(_ folded: String) -> String {
        "\(folded.count):\(folded)\(GroupFrame.default.asString)"
    }
}
