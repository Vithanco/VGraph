extension VGraph {

    public static let DEFAULT_ERROR_NODETYPE_NAME: String = "Default Error NodeType"
    public static let defaultErrorNodeType: NodeType = NodeType(string: DEFAULT_ERROR_NODETYPE_NAME)

    func addDefaulErrorNodeType() throws(VError) -> VGraph {
        return try self.add(nodeType: VGraph.defaultErrorNodeType)
            .set(
                nodeType: VGraph.defaultErrorNodeType,
                attribute: Attributes.Edge.color.attribute(VColor.red))
    }

}
