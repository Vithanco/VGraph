import VGraph

/// Uses struct (value type) to avoid reference counting overhead in WASM.
struct ParserStack {
    let currentNode: Node?
    let currentGroup: Group?
    let currentEdge: Edge?

    init(
        currentNode: Node? = nil,
        currentGroup: Group? = nil,
        currentEdge: Edge? = nil
    ) {
        self.currentNode = currentNode
        self.currentGroup = currentGroup
        self.currentEdge = currentEdge
    }
}
