public typealias AttributeContainer = [Attribute.Id: String]

extension AttributeContainer {
    public func add(_ def: AttributeDefinition, value: String) -> Self {
        var result = self
        result[def.id] = value.asString
        return result
    }

    public func add(_ def: AttributeDefinition) -> Self {
        var result = self
        result[def.id] = def.defaultValue
        return result
    }

    public func isEqual(to other: AttributeContainer) -> Bool {
        if self.count == other.count {
            for (key, value) in self {
                guard let otherValue = other[key] else {
                    return false
                }
                if otherValue != value {
                    return false
                }
            }
        }
        return true
    }

    public func value(for attr: AttributeDefinition) -> String? {
        return self[attr.id]
    }

    public func value<T: AttributeType>(for attr: TypedAttributeDefinition<T>) -> T {
        if let value = self[attr.id], let result = try? T.fromString(value) {
            return result
        }
        return attr.defaultValue
    }
}

public func combine(parent: AttributeContainer, child: AttributeContainer) -> AttributeContainer {
    var result = parent
    for (key, value) in child { result[key] = value }
    return result
}
