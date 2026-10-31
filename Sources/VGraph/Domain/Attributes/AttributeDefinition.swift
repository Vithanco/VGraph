public struct AttributeDefinition: VProtocol {
    public typealias Id = Identifier<AttributeDefinition>
    public let id: Id
    public let name: String
    public let description: String
    public let defaultValue: String
    public let target: AttributeTarget
    public var typeAsString: String

    public init(
        id: Id, name: String, description: String, defaultValue: String, target: AttributeTarget,
        typeAsString: String
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.defaultValue = defaultValue
        self.target = target
        self.typeAsString = typeAsString
    }

    public init<T: AttributeType>(
        id: Id,
        name: String,
        description: String,
        defaultValue: String,
        target: AttributeTarget,
        type: T.Type
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.defaultValue = defaultValue
        self.target = target
        self.typeAsString = type.typeName
    }

    /// The key used for VGL export, derived from the attribute id.
    /// e.g., id "group.borderWidth" → "borderwidth", id "node.fontsize" → "fontsize"
    public var vglKey: String {
        if let dotIndex = id.description.lastIndex(of: ".") {
            return String(id.description[id.description.index(after: dotIndex)...]).lowercased()
        }
        return id.description.lowercased()
    }

    var asAttribute: Attribute {
        return Attribute(definition: self, value: defaultValue)
    }

    public func attribute(fromString: String) throws(VError) -> Attribute {
        return Attribute(definition: self, value: fromString)
    }

    public func attribute<AType: AttributeType>(fromValue: AType) -> Attribute {
        assert(AType.typeName == self.typeAsString, "it is \(self.typeAsString) instead of \(AType.typeName)")
        return Attribute(definition: self, value: fromValue.asString)
    }

    /// A value that fails to parse is equal only to the same spelling.
    public func isEqual(_ stringValue1: String, _ stringValue2: String) -> Bool {
        guard stringValue1 != stringValue2 else { return true }
        switch typeAsString {
        case "Double": return parsedEqual(stringValue1, stringValue2, Double.self)
        case "Int": return parsedEqual(stringValue1, stringValue2, Int.self)
        case "Bool": return parsedEqual(stringValue1, stringValue2, Bool.self)
        default: return false
        }
    }

    private func parsedEqual<T: AttributeType>(_ stringValue1: String, _ stringValue2: String, _: T.Type) -> Bool {
        guard let v1 = try? T.fromString(stringValue1), let v2 = try? T.fromString(stringValue2) else { return false }
        return v1 == v2
    }

    public func isLessThan(_ stringValue1: String, _ stringValue2: String) throws(VError) -> Bool {
        switch typeAsString {
        case "Double":
            let v1 = try Double.fromString(stringValue1)
            let v2 = try Double.fromString(stringValue2)
            return v1 < v2

        case "Int":
            let v1 = try Int.fromString(stringValue1)
            let v2 = try Int.fromString(stringValue2)
            return v1 < v2

        case "Bool":
            let v1 = try Bool.fromString(stringValue1)
            let v2 = try Bool.fromString(stringValue2)
            // false < true
            return !v1 && v2

        case "String":
            return stringValue1 < stringValue2

        default:
            throw VError.attributeTypeNotComparable(typeAsString)
        }
    }
}

public struct TypedAttributeDefinition<T: AttributeType>: VProtocol {
    public typealias Id = Identifier<AttributeDefinition>
    public let id: Id
    public let name: String
    public let description: String
    public let defaultValue: T
    public let target: AttributeTarget

    public init(
        id: Id,
        name: String,
        description: String,
        defaultValue: T,
        target: AttributeTarget
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.defaultValue = defaultValue
        self.target = target
    }

    var asAttribute: Attribute {
        return Attribute(definition: self.asDefinition, value: defaultValue.asString)
    }

    public var asDefinition: AttributeDefinition {
        return AttributeDefinition(
            id: id,
            name: name,
            description: description,
            defaultValue: defaultValue.asString,
            target: target,
            typeAsString: T.typeName
        )
    }

    public func attribute(fromString: String) throws(VError) -> Attribute {
        let parsed = try T.fromString(fromString)
        return Attribute(definition: self.asDefinition, value: parsed.asString)
    }

    public func attribute(_ withValue: T) throws(VError) -> Attribute {
        return Attribute(definition: self.asDefinition, value: withValue.asString)
    }

    /// Cannot fail, so a notation can state its values as data.
    public func callAsFunction(_ value: T) -> Attribute {
        Attribute(definition: asDefinition, value: value.asString)
    }

    public func value(fromString: String) throws(VError) -> T {
        return try T.fromString(fromString)
    }
}
