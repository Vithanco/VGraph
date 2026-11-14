public typealias AttributeDefContainer = [Attribute.Id: AttributeDefinition]

extension AttributeDefContainer {
    public init(_ definitions: [AttributeDefinition]) {
        self.init()
        for definition in definitions { self[definition.id] = definition }
    }
}

public protocol AttributeRegistry {
    func find(attributeId: Attribute.Id) -> (AttributeDefinition)?
    func define(_ definition: AttributeDefinition) throws(VError) -> Self
}
