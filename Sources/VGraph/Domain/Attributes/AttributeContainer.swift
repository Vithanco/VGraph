public typealias AttributeContainer = [Attribute.Id: String]

extension AttributeContainer {
    public func value(for definition: AttributeDefinition) -> String? {
        return self[definition.id]
    }

    public func value<T: AttributeType>(for definition: TypedAttributeDefinition<T>) -> T {
        self[definition.id].flatMap { try? T.fromString($0) } ?? definition.defaultValue
    }
}
