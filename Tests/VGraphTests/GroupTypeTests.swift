import TestSupport
import Testing

@testable import VGraph

@Suite
struct GroupTypeTests {

    let group1 = Group(rawValue: "group1")
    let n1 = Node("n1")
    let nt1 = NodeType("nt1")
    let team = GroupType(string: "Team")

    private func baseGraph() throws(VError) -> VGraph {
        var graph = try VGraph()
            .defineStandardAttributes()
            .add(nodeType: nt1)
        graph = try Notations.FoldGroups.addExtension(addTo: graph)
        return graph
    }

    private func customFolded() -> NodeStyleLayout {
        return .nodeText(color: SemanticColor(id: "test.system.folded", lightHex: "#0b5cad"))
    }

    private func groupNode(for group: Group) -> Node {
        return Node(group)
    }

    // MARK: - Assigning and reading a group's type

    @Test("Given a group assigned a group type, when its type is read back, then it reports that type")
    func groupReportsAssignedType() throws(VError) {
        var graph = try baseGraph().add(group: group1)
        graph = try graph.typing(group: group1, as: team)

        let readBack = graph.groupType(of: group1)
        #expect(readBack == team)
    }

    @Test("Given a group with no assigned type, when its type is requested, then no group type is present")
    func untypedGroupHasNoType() throws(VError) {
        let graph = try baseGraph().add(group: group1)

        let readBack = graph.groupType(of: group1)
        #expect(readBack == nil)
    }

    @Test("Given a typed group, when it is typed as nothing, then it is a plain group again")
    func typingAsNothingMakesAGroupPlain() throws(VError) {
        let graph = try baseGraph().add(group: group1).typing(group: group1, as: team)
            .typing(group: group1, as: nil)
        #expect(graph.groupType(of: group1) == nil)
    }

    @Test("Given a typed group, when it is deleted and added again, then the new group is plain")
    func aDeletedGroupForgetsItsType() throws(VError) {
        let graph = try baseGraph().add(group: group1).typing(group: group1, as: team)
            .delete(group: group1).add(group: group1)
        #expect(graph.groupType(of: group1) == nil)
    }

    /// ADR-0030: nothing is inherited from an enclosing group, the type included.
    @Test("Given a plain group inside a typed one, when its style resolves, then it is not styled as its parent")
    func aPlainGroupInsideATypedOneIsNotStyledAsIt() throws(VError) {
        let child = Group(rawValue: "child")
        let graph = try baseGraph().ensureUnknownGroupType().add(group: group1)
            .add(group: child, childOf: group1)
            .typing(group: group1, as: GroupType.unknown)
        #expect(graph.groupType(of: child) == nil)
        #expect(graph.resolvedGroupStyle(child) == nil)
    }

    // MARK: - Resolving style from the type

    @Test("Given a group type with a defined style, when a group of that type is folded, then the collapsed box uses the type's folded style")
    func foldedGroupUsesItsTypesFoldedStyle() throws(VError) {
        let style = GroupStyle(folded: customFolded(), unfolded: .default)
        var graph = try baseGraph()
            .add(group: group1)
            .add(node: n1, type: nt1, group: group1)
            .add(groupType: team)
        graph = try graph.set(groupType: team, attribute: Attributes.Group.groupStyle.attribute(style))
        graph = try graph.typing(group: group1, as: team)
        graph = try graph.set(group: group1, def: Attributes.Group.isFolded, value: true)

        let result = try applyFoldingLayoutStep(to: graph)

        let proxyStyle = try result.get(node: groupNode(for: group1), attribute: Attributes.Node.style)
        let expected = try NodeStyleLayout.fromString(customFolded().asString)
        #expect(proxyStyle == expected)
    }

    @Test("Given a group whose type is styled but that also has its own style override, when folded, then the collapsed box uses the override")
    func perGroupOverrideBeatsTypeStyle() throws(VError) {
        let typeStyle = GroupStyle(folded: .empty, unfolded: .default)
        let overrideFolded = customFolded()
        let overrideStyle = GroupStyle(folded: overrideFolded, unfolded: .default)
        var graph = try baseGraph()
            .add(group: group1)
            .add(node: n1, type: nt1, group: group1)
            .add(groupType: team)
        graph = try graph.set(groupType: team, attribute: Attributes.Group.groupStyle.attribute(typeStyle))
        graph = try graph.typing(group: group1, as: team)
        graph = try graph.set(group: group1, attribute: Attributes.Group.groupStyle.attribute(overrideStyle))
        graph = try graph.set(group: group1, def: Attributes.Group.isFolded, value: true)

        let result = try applyFoldingLayoutStep(to: graph)

        let proxyStyle = try result.get(node: groupNode(for: group1), attribute: Attributes.Node.style)
        let expected = try NodeStyleLayout.fromString(overrideFolded.asString)
        #expect(proxyStyle == expected)
    }

    // MARK: - Enumerating the registered types

    @Test("Given group types registered on a graph, when the graph is asked for its group types, then it lists them")
    func registeredGroupTypesAreEnumerable() throws(VError) {
        let guild = GroupType(string: "Guild")
        let graph = try baseGraph()
            .add(groupType: team)
            .add(groupType: guild)

        #expect(graph.groupTypes == [team, guild])
    }

    /// ADR-0030: the registry is part of the notation definition, not a value.
    @Test("Given a registered group type and a declared icon, when the root's attributes are read, then neither is among them")
    func registriesAreNotAttributes() throws(VError) {
        let artwork = IconArtwork(width: 24, height: 24, path: "M0 0L24 24")
        let graph = try baseGraph().add(groupType: team).add(icon: "mark", artwork: artwork)
        #expect(try graph.getGraphAttributes().isEmpty)
        #expect(graph.groupTypes == [team])
        #expect(graph.declaredIcons["mark"] == artwork)
    }

    @Test("Given declared checks and transforms, when the root's attributes are read, then neither is among them")
    func declaredChecksAndTransformsAreNotAttributes() throws(VError) {
        let graph = try baseGraph()
            .declaring(qualityChecks: [QualityCheckSpec(name: "treeStructure")])
            .declaring(transforms: ["identity"])
        #expect(try graph.getGraphAttributes().isEmpty)
        #expect(graph.notationDefinition.declaredQualityChecks == [QualityCheckSpec(name: "treeStructure")])
        #expect(graph.notationDefinition.declaredTransforms == ["identity"])
    }

    @Test("Given a graph with no group types registered, when it is asked for them, then the list is empty")
    func unregisteredGraphEnumeratesNothing() throws(VError) {
        #expect(try baseGraph().groupTypes.isEmpty)
    }

    @Test("Given a registered group type, when a name is checked against the graph, then only registered names are recognised")
    func membershipFollowsRegistration() throws(VError) {
        let graph = try baseGraph().add(groupType: team)

        #expect(graph.has(groupTypeName: "Team"))
        #expect(!graph.has(groupTypeName: "SystemBoundry"))
    }

    // MARK: - The unknown group type

    @Test("Given a graph needing the unknown group type twice, when it is ensured, then it is registered once")
    func unknownGroupTypeIsEnsuredOnce() throws(VError) {
        let graph = try baseGraph()
            .ensureUnknownGroupType()
            .ensureUnknownGroupType()

        #expect(graph.groupTypes == [GroupType.unknown])
    }

    @Test("Given a group of the unknown type, when its style resolves, then the boundary is drawn in the error colour")
    func unknownGroupTypeDrawsRedChrome() throws(VError) {
        var graph = try baseGraph().ensureUnknownGroupType().add(group: group1)
        graph = try graph.typing(group: group1, as: GroupType.unknown)

        let style = graph.resolvedGroupStyle(group1)
        #expect(style?.unfolded.borderColor.asString == GroupType.unknownChrome.borderColor.asString)
    }

    @Test("Given a group carrying the unknown type, when quality is analysed, then it is reported as an error")
    func unknownGroupTypeIsReported() throws(VError) {
        var graph = try baseGraph().ensureUnknownGroupType().add(group: group1)
        graph = try graph.set(group: group1, attribute: Attributes.Group.label.attribute("Banking"))
        graph = try graph.typing(group: group1, as: GroupType.unknown)

        let messages = GenericQualityChecks.unknownGroupTypes(graph: graph)

        #expect(messages.count == 1)
        #expect(messages[0].severity == .error)
        #expect(messages[0].message.contains("Banking"))
    }

    @Test("Given only well-typed and plain groups, when quality is analysed, then nothing is reported")
    func wellTypedGroupsAreNotReported() throws(VError) {
        var graph = try baseGraph().add(groupType: team).add(group: group1)
        graph = try graph.typing(group: group1, as: team)

        #expect(GenericQualityChecks.unknownGroupTypes(graph: graph).isEmpty)
    }

    @Test("Given a group inside a typed parent, when quality is analysed, then the child's inherited type is not mistaken for its own")
    func inheritedTypeIsNotTheChildsOwn() throws(VError) {
        let child = Group(rawValue: "child")
        var graph = try baseGraph().ensureUnknownGroupType().add(group: group1)
        graph = try graph.add(group: child, childOf: group1)
        graph = try graph.typing(group: group1, as: GroupType.unknown)

        #expect(GenericQualityChecks.unknownGroupTypes(graph: graph).count == 1)
    }

    @Test("Given a group whose type defines no style, when the group is folded, then the collapsed box keeps the default folded appearance")
    func typedGroupWithoutTypeStyleUsesDefault() throws(VError) {
        var graph = try baseGraph()
            .add(group: group1)
            .add(node: n1, type: nt1, group: group1)
        graph = try graph.set(group: group1, attribute: Attributes.Group.label.attribute("Plain"))
        graph = try graph.typing(group: group1, as: team)
        graph = try graph.set(group: group1, def: Attributes.Group.isFolded, value: true)

        let result = try applyFoldingLayoutStep(to: graph)

        let proxyStyle = try result.get(node: groupNode(for: group1), attribute: Attributes.Node.style)
        let base = NodeStyleLayout.foldedGroupNode(
            label: "Plain",
            count: 1,
            fill: Notations.FoldGroups.foldedGroupFill,
            border: Notations.FoldGroups.foldedGroupBorder,
            textColor: Notations.FoldGroups.foldedGroupText
        )
        let expected = try NodeStyleLayout.fromString(base.asString)
        #expect(proxyStyle == expected)
    }
}
