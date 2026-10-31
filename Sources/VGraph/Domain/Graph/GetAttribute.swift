public protocol GetAttribute {
    func get(node: Node, attribute: AttributeDefinition) throws(VError) -> String
    func get(edge: Edge.Id, attribute: AttributeDefinition) throws(VError) -> String
    func get(nodeType: NodeType, attribute: AttributeDefinition) throws(VError) -> String
    func get(edgeType: EdgeType.Id, attribute: AttributeDefinition) throws(VError) -> String
    func get(group: Group, attribute: AttributeDefinition) throws(VError) -> String
}

public protocol GetElement {
    func has(node: Node) -> Bool
    func get(edge: Edge.Id) -> Edge?
    func has(nodeType: NodeType) -> Bool
    func get(edgeType: EdgeType.Id) -> EdgeType?
    func has(group: Group) -> Bool
}

public protocol SetAttribute: GetAttribute {
    func set(node: Node, attribute: Attribute) throws(VError) -> Self
    func set(edge: Edge.Id, attribute: Attribute) throws(VError) -> Self
    func set(nodeType: NodeType, attribute: Attribute) throws(VError) -> Self
    func set(edgeType: EdgeType.Id, attribute: Attribute) throws(VError) -> Self
    func set(group: Group?, attribute: Attribute) throws(VError) -> Self
    func set(graphAttribute: Attribute) throws(VError) -> Self
}

extension SetAttribute {
    public func set(node: Node, def: AttributeDefinition, value: String) throws(VError) -> Self {
        return try set(node: node, attribute: Attribute(definition: def, value: value))
    }

    public func set(edge: Edge.Id, def: AttributeDefinition, value: String) throws(VError) -> Self {
        return try set(edge: edge, attribute: Attribute(definition: def, value: value))
    }

    public func set(nodeType: NodeType, def: AttributeDefinition, value: String) throws(VError) -> Self {
        return try set(nodeType: nodeType, attribute: Attribute(definition: def, value: value))
    }

    public func set(edgeType: EdgeType.Id, def: AttributeDefinition, value: String) throws(VError) -> Self {
        return try set(edgeType: edgeType, attribute: Attribute(definition: def, value: value))
    }

    public func set(group: Group, def: AttributeDefinition, value: String) throws(VError) -> Self {
        return try set(group: group, attribute: Attribute(definition: def, value: value))
    }

    public func set(graphAttribute: AttributeDefinition, value: String) throws(VError) -> Self {
        return try set(graphAttribute: Attribute(definition: graphAttribute, value: value))
    }

    public func set<T>(node: Node, def: TypedAttributeDefinition<T>, value: T) throws(VError) -> Self {
        return try set(node: node, attribute: Attribute(definition: def.asDefinition, value: value.asString))
    }

    public func set<T>(edge: Edge.Id, def: TypedAttributeDefinition<T>, value: T) throws(VError) -> Self {
        return try set(edge: edge, attribute: Attribute(definition: def.asDefinition, value: value.asString))
    }

    public func set<T>(edge: Edge, def: TypedAttributeDefinition<T>, value: T) throws(VError) -> Self {
        return try set(edge: edge.id, attribute: Attribute(definition: def.asDefinition, value: value.asString))
    }

    public func set<T>(nodeType: NodeType, def: TypedAttributeDefinition<T>, value: T) throws(VError) -> Self {
        return try set(nodeType: nodeType, attribute: Attribute(definition: def.asDefinition, value: value.asString))
    }

    public func set<T>(edgeType: EdgeType.Id, def: TypedAttributeDefinition<T>, value: T) throws(VError) -> Self {
        return try set(edgeType: edgeType, attribute: Attribute(definition: def.asDefinition, value: value.asString))
    }

    public func set<T>(group: Group, def: TypedAttributeDefinition<T>, value: T) throws(VError) -> Self {
        return try set(group: group, attribute: Attribute(definition: def.asDefinition, value: value.asString))
    }

    public func set<T>(graphAttribute: TypedAttributeDefinition<T>, value: T) throws(VError) -> Self {
        return try set(graphAttribute: Attribute(definition: graphAttribute.asDefinition, value: value.asString))
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
