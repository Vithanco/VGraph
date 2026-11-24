import TestSupport
import Testing

@testable import VGraph

/// ADR-0032: a group is plain (optionally with a group type) or detailed (with a
/// node type), never both.
@Suite
struct DetailedNodeTests {

    let ibs = Group(rawValue: "ibs")
    let softwareSystem = NodeType("SoftwareSystem")
    let organization = GroupType(rawValue: "Organisation")

    private func graph() throws(VError) -> VGraph {
        try VGraph().adding(nodeType: softwareSystem).adding(group: ibs)
    }

    @Test("Given a detailed node, when it is given a group type, then it is a plain group again")
    func aGroupTypeReplacesTheNodeType() throws(VError) {
        let graph = try graph().typing(group: ibs, as: softwareSystem).typing(group: ibs, as: organization)

        #expect(graph.nodeType(of: ibs) == nil)
        #expect(graph.groupType(of: ibs) == organization)
    }

    @Test("Given a plain typed group, when it is typed as a node type, then it loses its group type")
    func aNodeTypeReplacesTheGroupType() throws(VError) {
        let graph = try graph().typing(group: ibs, as: organization).typing(group: ibs, as: softwareSystem)

        #expect(graph.groupType(of: ibs) == nil)
        #expect(graph.nodeType(of: ibs) == softwareSystem)
    }

    @Test("Given a detailed node, when it is deleted and added again, then the new group is plain")
    func aDeletedDetailedNodeForgetsItsType() throws(VError) {
        let graph = try graph().typing(group: ibs, as: softwareSystem).deleting(group: ibs).adding(group: ibs)

        #expect(graph.nodeType(of: ibs) == nil)
    }

    @Test("Given a detailed node with values in the model and a view, when its last detail goes, then the node holds them and no group-only value")
    func anEmptiedDetailedNodeKeepsItsValuesAsANode() throws {
        let container = NodeType("Container")
        let web = Node("web")
        let red = try Attributes.Node.backgroundColor.attribute(fromString: "#ff0000")
        let graph = try graph().adding(nodeType: container)
            .typing(group: ibs, as: softwareSystem)
            .adding(node: web, type: container, group: ibs)
            .setting(group: ibs, attribute: Attributes.Node.label("IBS"))
            .setting(group: ibs, attribute: Attributes.Group.isFolded(true))
            .declaring(view: ViewDeclaration(name: "v"))
            .settingInView("v", red, for: ItemKey(ibs))

        let emptied = try graph.deleting(node: web).removingEmptied(from: ibs)

        let node = ItemKey(Node("ibs"))
        #expect(try emptied.attributes(in: .model, of: node) == [Attributes.Node.label.id: "IBS"])
        #expect(try emptied.attributes(inView: "v", of: node)[red.id] == red.stringValue)
        #expect(try emptied.attributes(in: .model, of: ItemKey(ibs)).isEmpty)
    }

    @Test("Typing a group that does not exist fails")
    func typingAMissingGroupFails() throws {
        #expect(throws: VError.groupNotFound(Group(rawValue: "nope"))) {
            try graph().typing(group: Group(rawValue: "nope"), as: softwareSystem)
        }
    }
}
