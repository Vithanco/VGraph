public typealias AttributeDefContainer = [Attribute.Id: AttributeDefinition]

extension AttributeDefContainer {
    public init(_ definitions: [AttributeDefinition]) {
        self.init()
        for definition in definitions { self[definition.id] = definition }
    }
}

public func combine(parent: AttributeDefContainer, child: AttributeDefContainer) -> AttributeDefContainer {
    var result = parent
    for (key, value) in child { result[key] = value }
    return result
}

public protocol AttributeRegistry {
    func find(attributeId: Attribute.Id) -> (AttributeDefinition)?
    func define(_ definition: AttributeDefinition) throws(VError) -> Self
}
