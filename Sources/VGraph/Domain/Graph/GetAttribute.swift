public protocol GetAttribute {
    func get(node: Node, attribute: AttributeDefinition) throws(VError) -> String
    func get(edge: Edge.Id, attribute: AttributeDefinition) throws(VError) -> String
    func get(nodeType: NodeType, attribute: AttributeDefinition) throws(VError) -> String
    func get(edgeType: EdgeType.Id, attribute: AttributeDefinition) throws(VError) -> String
    func get(group: Group, attribute: AttributeDefinition) throws(VError) -> String
}

public protocol SetAttribute: GetAttribute {
    func setting(node: Node, attribute: Attribute) throws(VError) -> Self
    func setting(edge: Edge.Id, attribute: Attribute) throws(VError) -> Self
    func setting(nodeType: NodeType, attribute: Attribute) throws(VError) -> Self
    func setting(edgeType: EdgeType.Id, attribute: Attribute) throws(VError) -> Self
    func setting(group: Group, attribute: Attribute) throws(VError) -> Self
    func setting(graphAttribute: Attribute) throws(VError) -> Self
}

extension SetAttribute {
    public func setting(edge: Edge.Id, def: AttributeDefinition, value: String) throws(VError) -> Self {
        return try setting(edge: edge, attribute: Attribute(definition: def, value: value))
    }
}

extension GetAttribute {
    public func get<T>(node: Node, attribute: TypedAttributeDefinition<T>) throws(VError) -> T {
        return try T.fromString(get(node: node, attribute: attribute.asDefinition))
    }
    public func get<T>(edge: Edge.Id, attribute: TypedAttributeDefinition<T>) throws(VError) -> T {
        return try T.fromString(get(edge: edge, attribute: attribute.asDefinition))
    }
    public func get<T>(nodeType: NodeType, attribute: TypedAttributeDefinition<T>) throws(VError) -> T {
        return try T.fromString(get(nodeType: nodeType, attribute: attribute.asDefinition))
    }
    public func get<T>(edgeType: EdgeType.Id, attribute: TypedAttributeDefinition<T>) throws(VError) -> T {
        return try T.fromString(get(edgeType: edgeType, attribute: attribute.asDefinition))
    }
    public func get<T>(group: Group, attribute: TypedAttributeDefinition<T>) throws(VError) -> T {
        return try T.fromString(get(group: group, attribute: attribute.asDefinition))
    }

}

extension VGraph {
    public func get<T: AttributeType>(attribute: TypedAttributeDefinition<T>) throws(VError) -> T {
        return try T.fromString(get(graphAttribute: attribute.asDefinition))
    }
}
