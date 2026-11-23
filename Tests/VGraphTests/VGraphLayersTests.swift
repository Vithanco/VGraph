import Testing

@testable import VGLanguage
@testable import VGraph

/// VGraph's attributes as ADR-0030 has them: set in layers, resolved along an
/// element's chain (element, then its type), never through enclosing groups.
@Suite("VGraph on layers")
struct VGraphLayersTests {
    let question = NodeType("Question")
    let answer = NodeType("Answer")
    let q1 = Node("q1")
    let outer = Group(rawValue: "outer")
    let inner = Group(rawValue: "inner")

    private func graph() throws(VError) -> VGraph {
        try VGraph()
            .adding(nodeType: question).adding(nodeType: answer)
            .adding(group: outer).adding(group: inner, childOf: outer)
            .adding(node: q1, type: question, group: inner)
    }

    @Test("Given a node attribute, when it is written to a plain group, then the group refuses it")
    func aPlainGroupRefusesANodeAttribute() throws(VError) {
        #expect(throws: VError.wrongTarget(is: .node, insteadOf: .group)) {
            try graph().setting(group: inner, attribute: Attributes.Node.fontsize.attribute(30))
        }
    }

    @Test("Given a value on the root, when a node resolves the same attribute, then the root's value does not apply")
    func aNodeInheritsNothingFromTheRoot() throws(VError) {
        let styled = try graph().setting(graphAttribute: Attributes.Node.fontsize.attribute(30))
        #expect(try styled.get(node: q1, attribute: Attributes.Node.fontsize) == Attributes.Node.fontsize.defaultValue)
    }

    @Test("Given a value on a node's group, when the node resolves the same attribute, then the group's value does not apply")
    func aNodeTakesNothingFromItsGroup() throws(VError) {
        let labeled = try graph().setting(group: inner, attribute: Attributes.Group.label.attribute("Inner"))
        #expect(try labeled.get(node: q1, attribute: Attributes.Group.label) == Attributes.Group.label.defaultValue)
    }

    @Test("Given values on the graph, the type and the node, when the node's attributes are read, then only the type's and its own are held")
    func aNodesAttributesHoldOnlyItsOwnAndItsTypes() throws(VError) {
        let styled = try graph()
            .setting(graphAttribute: Attributes.Node.tooltip.attribute("graph"))
            .setting(nodeType: question, attribute: Attributes.Node.label.attribute("type"))
            .setting(node: q1, attribute: Attributes.Node.position.attribute(VPoint(x: 42, y: 42).asString))
        let held = try styled.attributes(node: q1)
        #expect(held.count == 2)
        #expect(held.value(for: Attributes.Node.label) == "type")
        #expect(held.value(for: Attributes.Node.position) == VPoint(x: 42, y: 42).asString)
    }

    @Test("Given a labelled parent group, when its child resolves its label, then it has its own or the default")
    func aGroupInheritsNothingFromItsParent() throws(VError) {
        let labeled = try graph().setting(group: outer, attribute: Attributes.Group.label.attribute("Outer"))
        #expect(try labeled.get(group: inner, attribute: Attributes.Group.label) == Attributes.Group.label.defaultValue)
    }

    @Test("Given a value on a node's type, when the node resolves it, then the type's value applies")
    func aNodeFallsBackToItsType() throws(VError) {
        let typed = try graph().setting(nodeType: question, attribute: Attributes.Node.fontsize.attribute(30))
        #expect(try typed.get(node: q1, attribute: Attributes.Node.fontsize) == 30.0)
    }

    @Test("Given a node value equal to its type's, when the node's own values are read, then it is not among them")
    func aNodeRepeatingItsTypeHoldsNothing() throws(VError) {
        let repeated = try graph().setting(nodeType: question, attribute: Attributes.Node.fontsize.attribute(30))
            .setting(node: q1, attribute: Attributes.Node.fontsize.attribute(30))
        #expect(repeated.ownAttributes(node: q1)[Attributes.Node.fontsize.id] == nil)
    }

    @Test("Given a node with its own value, when it is retyped to a type with that value, then the value is dropped")
    func retypingPrunesAgainstTheNewType() throws(VError) {
        let retyped = try graph().setting(nodeType: answer, attribute: Attributes.Node.fontsize.attribute(30))
            .setting(node: q1, attribute: Attributes.Node.fontsize.attribute(30))
            .settingNodeType(node: q1, type: answer)
        #expect(retyped.ownAttributes(node: q1)[Attributes.Node.fontsize.id] == nil)
        #expect(try retyped.get(node: q1, attribute: Attributes.Node.fontsize) == 30.0)
    }

    @Test("Given an attribute the graph never defined, when it is written, then the write is refused")
    func anUndefinedAttributeCannotBeWritten() throws(VError) {
        let stranger = TypedAttributeDefinition<String>(
            id: "node.stranger", name: "stranger", description: "", defaultValue: "", target: .node)
        let graph = try graph()
        #expect(throws: VError.attributeNotFound(stranger.id)) {
            try graph.setting(node: q1, attribute: stranger.attribute("x"))
        }
    }

    @Test("Given a group with a colour in VGL, when it is parsed, then the colour is its background")
    func aGroupsColorIsItsBackground() throws {
        let parsed = try VGraphParser(logger: NoOpLogger()).parse(
            source: #"vgraph g: IBIS "G" { group box "Box" { color: lightblue; node q: Question "Q"; }; }"#)
        let background = try parsed.get(group: Group(rawValue: "box"), attribute: Attributes.Group.backgroundColor)
        #expect(background == VColor(named: "lightblue"))
    }

    @Test("Given an IBIS document, when it is parsed, then IBIS's type values are in the built-in layer")
    func aBuiltInNotationWritesTheBuiltInLayer() throws {
        let parsed = try VGraphParser(logger: NoOpLogger()).parse(
            source: #"vgraph g: IBIS "G" { node q: Question "Q"; }"#)
        let key = ItemKey(.nodeType, "Question")
        #expect(try !parsed.attributes(in: .builtin, of: key).isEmpty)
        #expect(try parsed.attributes(in: .vnotation, of: key).isEmpty)
        #expect(try parsed.attributes(in: .model, of: ItemKey(.node, "q"))[Attributes.Node.label.id] == "Q")
    }

    @Test("Given a document that needed the unknown node type, when it is parsed, then its style is in the engine layer")
    func theUnknownTypesAreTheEngines() throws(VError) {
        let graph = try VGraph().ensuringUnknownGroupType()
        let key = ItemKey(.groupType, GroupType.unknownPrefix)
        #expect(try !graph.attributes(in: .engine, of: key).isEmpty)
        #expect(try graph.attributes(in: .vnotation, of: key).isEmpty)
    }
}

/// Which layer each write lands in. The exporter writes the `vnotation` layer
/// back into the document, so a built-in notation's values must never reach it.
@Suite("Writes land in the right layer")
struct LayerRoutingTests {
    private func parse(_ source: String) throws -> VGraph {
        try VGraphParser(logger: NoOpLogger()).parse(source: source)
    }

    @Test(arguments: NotationRegistry.entries.map { $0.id })
    func aBuiltInNotationLeavesTheVNotationLayerEmpty(_ notation: String) throws {
        let graph = try parse(#"vgraph g: \#(notation) "G" { }"#)
        #expect(graph.attributeStore.keys(in: .vnotation).isEmpty, "\(graph.attributeStore.keys(in: .vnotation))")
    }

    @Test
    func anExtensionNamedInTheHeaderLeavesTheVNotationLayerEmpty() throws {
        let graph = try parse(#"vgraph g: IBIS, Annotation "G" { }"#)
        #expect(graph.has(nodeType: Notations.Annotation.annotation))
        #expect(graph.attributeStore.keys(in: .vnotation).isEmpty, "\(graph.attributeStore.keys(in: .vnotation))")
    }

    @Test
    func aVNotationAddsOnlyWhatItsBlockSays() throws {
        let plain = try parse(#"vgraph g: IBIS "G" { }"#)
        let extended = try parse(
            """
            vnotation Mine extends IBIS {
                node type: Extra [nodeStyle: withCategory, color: "#884499", category: "E"]
            }
            vgraph g: Mine "G" { }
            """)
        for key in plain.attributeStore.keys(in: .builtin) {
            #expect(try extended.attributes(in: .builtin, of: key) == plain.attributes(in: .builtin, of: key), "\(key)")
        }
        #expect(Set(extended.attributeStore.keys(in: .builtin)) == Set(plain.attributeStore.keys(in: .builtin)))
        #expect(extended.attributeStore.keys(in: .vnotation).allSatisfy { $0.id == "Extra" }, "\(extended.attributeStore.keys(in: .vnotation))")
    }

    @Test("The engine layer holds the unknown types and, on every type with a detailing, that its detailed nodes start folded")
    func theEngineLayerHoldsOnlyTheUnknownTypesAndTheFoldDefault() throws {
        #expect(try parse(#"vgraph g: IBIS "G" { node q: Question "Q"; }"#).attributeStore.keys(in: .engine).isEmpty)
        let broken = try parse(
            #"vgraph g: C4 "G" { group b: SystemBoundry "B" { node p: Person "P"; }; node x: Nonsense "X"; }"#)
        let detailed: Set<String> = ["SoftwareSystem", "Container", "Component"]
        for key in broken.attributeStore.keys(in: .engine) where !key.id.hasPrefix("__UNKNOWN") {
            #expect(key.kind == .nodeType && detailed.contains(key.id), "\(key)")
            #expect(try broken.attributes(in: .engine, of: key) == [Attributes.Group.isFolded.id: "true"], "\(key)")
        }
        #expect(Set(broken.attributeStore.keys(in: .engine).filter { !$0.id.hasPrefix("__UNKNOWN") }.map { $0.id }) == detailed)
    }
}

/// The graph is the only record of an element's type; the store asks it.
@Suite("Type links have one source")
struct TypeLinkSourceTests {
    @Test("Given a graph assembled from its parts, when a node resolves, then it goes through its type")
    func aNodeResolvesThroughTheGraphsOwnType() throws(VError) {
        let question = NodeType("Question")
        let styled = try VGraph().adding(nodeType: question)
            .setting(nodeType: question, attribute: Attributes.Node.fontsize.attribute(30))
        let structure = try VGraph().adding(nodeType: question)
            .adding(node: Node("q1"), type: question, group: Group.root)
        let assembled = VGraph(graph: structure.typedGraph, attributeStore: styled.attributeStore, groupStructure: structure.groupStructure)
        #expect(try assembled.get(node: Node("q1"), attribute: Attributes.Node.fontsize) == 30)
    }
}
