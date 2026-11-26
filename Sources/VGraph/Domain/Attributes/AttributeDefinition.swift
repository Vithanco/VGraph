public struct AttributeDefinition: VProtocol {
    public typealias Id = Identifier<AttributeDefinition>
    public let id: Id
    public let name: String
    public let description: String
    public let defaultValue: String
    public let target: AttributeTarget
    public let typeAsString: String
    /// Values stay strings (ADR-0030), so only the definition can tell what text
    /// read from VGL means in its type: `nil` where it is not of the type. Not part
    /// of the definition's identity.
    private let canonical: @Sendable (String) -> String?

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
        self.canonical = { $0 }
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
        self.canonical = { (try? T.fromString($0))?.asString }
    }

    public func accepts(_ value: String) -> Bool {
        canonical(value) != nil
    }

    /// Whether two spellings mean one value, as `LR` and `leftToRight` do.
    func readsAlike(_ left: String, _ right: String) -> Bool {
        guard left != right else { return true }
        guard let meaning = canonical(left) else { return false }
        return meaning == canonical(right)
    }

    public static func == (left: AttributeDefinition, right: AttributeDefinition) -> Bool {
        left.id == right.id && left.name == right.name && left.description == right.description
            && left.defaultValue == right.defaultValue && left.target == right.target
            && left.typeAsString == right.typeAsString
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(description)
        hasher.combine(defaultValue)
        hasher.combine(target)
        hasher.combine(typeAsString)
    }

    /// What a key written in VGL is matched against: VGL reads keys in any case.
    public var vglKey: String {
        camelCaseKey.lowercased()
    }

    /// The key as the guide spells it and export writes it: id "group.borderWidth" → "borderWidth".
    public var camelCaseKey: String {
        let text = id.description
        guard let dot = text.lastIndex(of: ".") else { return text }
        return String(text[text.index(after: dot)...])
    }

    public func attribute(fromString value: String) -> Attribute {
        return Attribute(definition: self, value: value)
    }

    /// A value that fails to parse is equal only to the same spelling.
    public func isEqual(_ left: String, _ right: String) -> Bool {
        guard left != right else { return true }
        switch typeAsString {
        case "Double": return parsedEqual(left, right, Double.self)
        case "Int": return parsedEqual(left, right, Int.self)
        case "Bool": return parsedEqual(left, right, Bool.self)
        default: return false
        }
    }

    private func parsedEqual<T: AttributeType>(_ left: String, _ right: String, _: T.Type) -> Bool {
        guard let leftValue = try? T.fromString(left), let rightValue = try? T.fromString(right) else { return false }
        return leftValue == rightValue
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

    public var asDefinition: AttributeDefinition {
        return AttributeDefinition(
            id: id,
            name: name,
            description: description,
            defaultValue: defaultValue.asString,
            target: target,
            type: T.self
        )
    }

    public func attribute(fromString text: String) throws(VError) -> Attribute {
        let parsed = try T.fromString(text)
        return Attribute(definition: self.asDefinition, value: parsed.asString)
    }

    /// Cannot fail, so a notation can state its values as data.
    public func callAsFunction(_ value: T) -> Attribute {
        Attribute(definition: asDefinition, value: value.asString)
    }

    public func value(fromString text: String) throws(VError) -> T {
        return try T.fromString(text)
    }
}
