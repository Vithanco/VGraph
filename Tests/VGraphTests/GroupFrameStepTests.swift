// An unfolded typed group is stamped with its GroupType's GroupFrame (dashed
// border, frame colour, transparent fill) rather than the plain-group look.

import TestSupport
import Testing

@testable import VGraph

@Suite("Group frame step")
struct GroupFrameStepTests {

    let member = NodeType("Member")
    let team = GroupType(rawValue: "Team")
    let border = SemanticColor(id: "test.team.border", lightHex: "#7a7a7a", darkHex: "#8f8f8f")
    let fill = SemanticColor(id: "test.team.fill", lightHex: "#00000000", darkHex: "#00000000")

    private func graphWithMember() throws -> VGraph {
        let frame = GroupFrame(cornerRadius: 8, borderDash: "8,4", borderColor: border, fill: fill)
        let graph = try VGraph().adding(nodeType: member).adding(groupType: team)
        return try graph.setting(
            groupType: team,
            attribute: Attributes.Group.groupStyle.attribute(GroupStyle(folded: .empty, unfolded: frame)))
    }

    private func adding(_ group: Group, holding node: Node, to graph: VGraph) throws -> VGraph {
        let result = try graph.adding(group: group, childOf: nil)
            .setting(group: group, attribute: Attributes.Group.id.attribute(fromString: group.id.id))
        return try result.adding(node: node, type: member, group: group)
    }

    /// A single unfolded Team group around one node.
    private func graphWithTeam() throws -> (VGraph, Group) {
        let core = Group(rawValue: "core")
        let graph = try adding(core, holding: Node(rawValue: "ann"), to: graphWithMember())
        return (try graph.typing(group: core, as: team), core)
    }

    /// Runs the real step, not the free function it wraps, so the `.foldGroups`
    /// prerequisite is genuinely exercised rather than merely satisfied.
    private func runFrameStep(_ graph: VGraph) throws -> VGraph {
        try Notations.groupFrameStep(graph.marking([.foldGroups]))
    }

    @Test func frameStepRefusesToRunBeforeFolding() throws {
        let (graph, _) = try graphWithTeam()

        #expect(throws: VError.pipelineContractViolated(step: "groupFrame", missing: ["foldGroups"])) {
            try Notations.groupFrameStep(graph)
        }
    }

    @Test func stampsDashAndCornerFromTheGroupTypesFrame() throws {
        let (graph, core) = try graphWithTeam()
        let out = try runFrameStep(graph)

        let dash: String = try out.get(group: core, attribute: Attributes.Group.borderDash)
        let corner: Double = try out.get(group: core, attribute: Attributes.Group.cornerRadius)

        // These come from the Team's GroupFrame, not the generic group defaults.
        #expect(dash == "8,4")
        #expect(dash != Attributes.Group.borderDash.defaultValue)  // generic default is "6,3"
        #expect(corner == 8)
    }

    @Test func stampsFrameColorAndTransparentFill() throws {
        let (graph, core) = try graphWithTeam()
        let out = try runFrameStep(graph)

        let stampedBorder: VColor = try out.get(group: core, attribute: Attributes.Group.borderColor)
        let stampedFill: VColor = try out.get(group: core, attribute: Attributes.Group.backgroundColor)

        // Compare canonically (colour round-trip is lossy for semantic ids).
        #expect(stampedBorder.asString == border.resolve(darkMode: false).asString)
        #expect(stampedFill.asString == fill.resolve(darkMode: false).asString)
        #expect(stampedFill.alphaComponent == 0)
    }

    @Test func leavesUntypedGroupsAlone() throws {
        let plain = Group(rawValue: "plain")
        let out = try runFrameStep(adding(plain, holding: Node(rawValue: "bob"), to: graphWithMember()))

        // No resolved GroupStyle → the group keeps the generic defaults.
        let dash: String = try out.get(group: plain, attribute: Attributes.Group.borderDash)
        #expect(dash == Attributes.Group.borderDash.defaultValue)
    }

    /// GroupFrame survives a canonical round-trip through its codec.
    @Test func frameRoundTrips() throws {
        let frame = GroupFrame(cornerRadius: 8, borderDash: "8,4", borderColor: border, fill: fill)
        let restored = try GroupFrame.fromString(frame.asString)
        #expect(restored.asString == frame.asString)
        #expect(restored.cornerRadius == 8)
        #expect(restored.borderDash == "8,4")
    }

    /// A solid (empty-dash) frame round-trips — the codec must preserve the empty field.
    @Test func solidFrameRoundTrips() throws {
        let frame = GroupFrame(cornerRadius: 4, borderDash: "")
        let restored = try GroupFrame.fromString(frame.asString)
        #expect(restored.borderDash == "")
        #expect(restored.cornerRadius == 4)
    }
}
