/// A node type's statement of which types its nodes are detailed by (ADR-0032).
public struct Detailing: VProtocol {
    public let nodeType: NodeType
    public let detailTypes: [NodeType]

    public init(nodeType: NodeType, detailTypes: [NodeType]) {
        self.nodeType = nodeType
        self.detailTypes = detailTypes
    }
}
