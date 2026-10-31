import TestSupport
import Testing

@testable import VGraph

/// ADR-0032: a group is plain (optionally with a group type) or detailed (with a
/// node type), never both.
@Suite
struct DetailedNodeTests {

    let ibs = Group(rawValue: "ibs")
    let softwareSystem = NodeType("SoftwareSystem")
    let organisation = GroupType(string: "Organisation")

    private func graph() throws(VError) -> VGraph {
        try VGraph().defineStandardAttributes().add(nodeType: softwareSystem).add(group: ibs)
    }

    @Test("Given a group typed as a node type, then it is a detailed node of that type and has no group type")
    func typingAsANodeTypeMakesADetailedNode() throws(VError) {
        let graph = try graph().typing(group: ibs, as: softwareSystem)

        #expect(graph.nodeType(of: ibs) == softwareSystem)
        #expect(graph.groupType(of: ibs) == nil)
    }

    @Test("Given a plain group, then it carries no node type")
    func aPlainGroupIsNotDetailed() throws(VError) {
        let graph = try graph().typing(group: ibs, as: organisation)

        #expect(graph.nodeType(of: ibs) == nil)
    }

    @Test("Given a detailed node, when it is given a group type, then it is a plain group again")
    func aGroupTypeReplacesTheNodeType() throws(VError) {
        let graph = try graph().typing(group: ibs, as: softwareSystem).typing(group: ibs, as: organisation)

        #expect(graph.nodeType(of: ibs) == nil)
        #expect(graph.groupType(of: ibs) == organisation)
    }

    @Test("Given a plain typed group, when it is typed as a node type, then it loses its group type")
    func aNodeTypeReplacesTheGroupType() throws(VError) {
        let graph = try graph().typing(group: ibs, as: organisation).typing(group: ibs, as: softwareSystem)

        #expect(graph.groupType(of: ibs) == nil)
        #expect(graph.nodeType(of: ibs) == softwareSystem)
    }

    @Test("Given a detailed node, when it is deleted and added again, then the new group is plain")
    func aDeletedDetailedNodeForgetsItsType() throws(VError) {
        let graph = try graph().typing(group: ibs, as: softwareSystem).delete(group: ibs).add(group: ibs)

        #expect(graph.nodeType(of: ibs) == nil)
    }

    @Test("Given a detailed node with values in the model and a view, when its last detail goes, then the node holds them and no group-only value")
    func anEmptiedDetailedNodeKeepsItsValuesAsANode() throws {
        let container = NodeType("Container")
        let web = Node("web")
        let red = try Attributes.Node.backgroundColor.attribute(fromString: "#ff0000")
        let graph = try graph().add(nodeType: container)
            .typing(group: ibs, as: softwareSystem)
            .add(node: web, type: container, group: ibs)
            .set(group: ibs, attribute: Attributes.Node.label.attribute("IBS"))
            .set(group: ibs, attribute: Attributes.Group.isFolded.attribute(true))
            .declaring(view: ViewDeclaration(name: "v"))
            .settingInView("v", red, for: VGraph.key(ibs))

        let emptied = try graph.delete(node: web).removingEmptied(from: ibs)

        let node = VGraph.key(Node("ibs"))
        #expect(try emptied.attributes(in: .model, of: node) == [Attributes.Node.label.id: "IBS"])
        #expect(try emptied.attributes(inView: "v", of: node)[red.id] == red.stringValue)
        #expect(try emptied.attributes(in: .model, of: VGraph.key(ibs)).isEmpty)
    }

    @Test("Typing a group that does not exist fails")
    func typingAMissingGroupFails() throws {
        #expect(throws: VError.self) {
            try graph().typing(group: Group(rawValue: "nope"), as: softwareSystem)
        }
    }
}
