public typealias AttributeDefContainer = [Attribute.Id: AttributeDefinition]

extension AttributeDefContainer {
    public init(_ definitions: [AttributeDefinition]) {
        self.init()
        for definition in definitions { self[definition.id] = definition }
    }
}
