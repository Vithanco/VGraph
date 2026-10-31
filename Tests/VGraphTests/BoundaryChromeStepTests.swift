// An unfolded typed group is stamped with its GroupType's BoundaryChrome (dashed
// border, boundary colour, transparent fill) rather than the generic cluster look.

import Testing

@testable import VGraph

@Suite("Boundary chrome step")
struct BoundaryChromeStepTests {

    let member = NodeType("Member")
    let team = GroupType(string: "Team")
    let border = SemanticColor(id: "test.team.border", lightHex: "#7a7a7a", darkHex: "#8f8f8f")
    let fill = SemanticColor(id: "test.team.fill", lightHex: "#00000000", darkHex: "#00000000")

    private func graphWithMember() throws -> VGraph {
        let chrome = BoundaryChrome(cornerRadius: 8, borderDash: "8,4", borderColor: border, fill: fill)
        let graph = try VGraph().defineStandardAttributes().add(nodeType: member).add(groupType: team)
        return try graph.set(
            groupType: team,
            attribute: Attributes.Group.groupStyle.attribute(GroupStyle(folded: .empty, unfolded: chrome)))
    }

    private func adding(_ group: Group, holding node: Node, to graph: VGraph) throws -> VGraph {
        let result = try graph.add(group: group, childOf: nil)
            .set(group: group, attribute: Attributes.Group.Id.attribute(fromString: group.id.id))
        return try result.add(node: node, type: member, group: group)
    }

    /// A single unfolded Team group around one node.
    private func graphWithTeam() throws -> (VGraph, Group) {
        let core = Group(rawValue: "core")
        let graph = try adding(core, holding: Node(rawValue: "ann"), to: graphWithMember())
        return (try graph.typing(group: core, as: team), core)
    }

    /// Runs the real step, not the free function it wraps, so the `.foldGroups`
    /// prerequisite is genuinely exercised rather than merely satisfied.
    private func runChrome(_ graph: VGraph) throws -> VGraph {
        try Notations.boundaryChromeStep(graph.marking([.foldGroups]))
    }

    @Test func chromeRefusesToRunBeforeFolding() throws {
        let (graph, _) = try graphWithTeam()

        #expect(throws: VError.self) {
            try Notations.boundaryChromeStep(graph)
        }
    }

    @Test func stampsDashAndCornerFromBoundaryType() throws {
        let (graph, core) = try graphWithTeam()
        let out = try runChrome(graph)

        let dash: String = try out.get(group: core, attribute: Attributes.Group.borderDash)
        let corner: Double = try out.get(group: core, attribute: Attributes.Group.cornerRadius)

        // These come from the Team's BoundaryChrome, not the generic group defaults.
        #expect(dash == "8,4")
        #expect(dash != Attributes.Group.borderDash.defaultValue)  // generic default is "6,3"
        #expect(corner == 8)
    }

    @Test func stampsBoundaryColourAndTransparentFill() throws {
        let (graph, core) = try graphWithTeam()
        let out = try runChrome(graph)

        let stampedBorder: VColor = try out.get(group: core, attribute: Attributes.Group.borderColor)
        let stampedFill: VColor = try out.get(group: core, attribute: Attributes.Group.backgroundColor)

        // Compare canonically (colour round-trip is lossy for semantic ids).
        #expect(stampedBorder.asString == border.resolve(darkMode: false).asString)
        #expect(stampedFill.asString == fill.resolve(darkMode: false).asString)
        #expect(stampedFill.alphaComponent == 0)
    }

    @Test func leavesUntypedGroupsAlone() throws {
        let plain = Group(rawValue: "plain")
        let out = try runChrome(adding(plain, holding: Node(rawValue: "bob"), to: graphWithMember()))

        // No resolved GroupStyle → the group keeps the generic defaults.
        let dash: String = try out.get(group: plain, attribute: Attributes.Group.borderDash)
        #expect(dash == Attributes.Group.borderDash.defaultValue)
    }

    /// BoundaryChrome survives a canonical round-trip through its codec.
    @Test func chromeRoundTrips() throws {
        let chrome = BoundaryChrome(cornerRadius: 8, borderDash: "8,4", borderColor: border, fill: fill)
        let restored = try BoundaryChrome.fromString(chrome.asString)
        #expect(restored.asString == chrome.asString)
        #expect(restored.cornerRadius == 8)
        #expect(restored.borderDash == "8,4")
    }

    /// A solid (empty-dash) boundary round-trips — the codec must preserve the empty field.
    @Test func solidBoundaryRoundTrips() throws {
        let chrome = BoundaryChrome(cornerRadius: 4, borderDash: "")
        let restored = try BoundaryChrome.fromString(chrome.asString)
        #expect(restored.borderDash == "")
        #expect(restored.cornerRadius == 4)
    }
}
