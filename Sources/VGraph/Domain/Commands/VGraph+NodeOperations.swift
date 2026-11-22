//
//  VGraph+NodeOperations.swift
//  VGraph
//
//  Its sibling in `VGraph+EdgeOperations.swift` grows a node off an existing one
//  and derives its type from the relationship. Here there is no relationship, so
//  the type is simply given — the notation has nothing to decide (ADR-0016).
//

extension VGraph {
    /// The returned node is the one to open an [[Inline edit]] on, or `nil` for a
    /// type that displays no text of its own — `addingRelated`'s contract, so an
    /// adapter treats the two creations alike.
    public func addingNode(
        ofType type: NodeType, in group: Group? = nil
    ) throws(VError) -> (VGraph, Node?) {
        let (result, newNode) = try addingPlaceholderNode(ofType: type, in: group ?? Group.root)
        return (result, nodeForInlineEdit(newNode, ofType: type))
    }

    /// `nil` for a type that displays no text of its own, so there is nothing
    /// to edit.
    func nodeForInlineEdit(_ node: Node, ofType type: NodeType) -> Node? {
        hasUserText(nodeType: type) ? node : nil
    }

    /// `group` is not optional: there is no such thing as a node in *no* group.
    /// The parser puts every top-level node under the root, and the exporter
    /// walks the group structure — so a node left out of it is created and
    /// then invisible.
    func addingPlaceholderNode(ofType type: NodeType, in group: Group) throws(VError) -> (VGraph, Node) {
        let newNode = newNodeId(for: type)
        return (try adding(placeholder: newNode, ofType: type, in: group), newNode)
    }

    /// For a caller that had to mint `node`'s id before changing the graph. The
    /// label is explicit, never absent — an absent label does not survive a
    /// reparse unchanged (ADR-0009).
    func adding(placeholder node: Node, ofType type: NodeType, in group: Group?) throws(VError) -> VGraph {
        try add(node: node, type: type, group: group).set(
            node: node,
            attribute: Attributes.Node.label.attribute(Attributes.Node.placeholderLabel))
    }
}
