public struct Attribute: VProtocol, CustomDebugStringConvertible {
    public typealias Id = AttributeDefinition.Id
    public var id: Id {
        return self.definition.id
    }
    public let definition: AttributeDefinition

    public let stringValue: String

    public init(definition: AttributeDefinition, value: String) {
        self.definition = definition
        self.stringValue = value.asString
    }

    public func updateValue(new: String) throws(VError) -> Attribute {
        return Attribute(definition: self.definition, value: new)
    }

    public var type: String {
        return definition.typeAsString
    }

    public static func == (lhs: Attribute, rhs: Attribute) -> Bool {
        return lhs.stringValue == rhs.stringValue
    }

    public func isEqual(to other: Attribute) -> Bool {
        return definition == definition && self.stringValue == other.stringValue
    }

    public var debugDescription: String {
        return stringValue
    }
}

extension String: AttributeType {
    public var asString: String {
        return self
    }

    public static let typeName = "String"

    public static func fromString(_ string: String) throws(VError) -> Self {
        return string
    }
}

extension Double: AttributeType {
    public static var typeName: String {
        "Double"
    }

    public static func fromString(_ string: String) throws(VError) -> Self {
        if let result = Double(string) {
            return result
        }
        throw .conversionError(from: string, to: "Double")
    }

    public var asString: String {
        return self.asString(decimals: 2)
    }
}

extension Bool: AttributeType {
    public var asString: String {
        return self ? "true" : "false"
    }

    public static let typeName = "Bool"

    public static func fromString(_ string: String) throws(VError) -> Self {
        return string.lowercased() == "true"
    }
}

extension Int: AttributeType {
    public var asString: String {
        return "\(self)"
    }

    public static let typeName = "Int"

    public static func fromString(_ string: String) throws(VError) -> Self {
        let result = Int(string)
        if result == nil {
            throw .conversionError(from: string, to: "Int")
        }
        return result!
    }
}

extension Optional: VProtocol where Wrapped: AttributeType {

}

extension Optional: AttributeType where Wrapped: AttributeType {
    public var asString: String {
        if case .some(let wrappedValue) = self {
            return wrappedValue.asString
        }
        return ""
    }

    public static var typeName: String {
        return "Optional<\(Wrapped.typeName)>"
    }

    public static func fromString(_ string: String) throws(VError) -> Self {
        if let wrappedValue = try? Wrapped.fromString(string) {
            return .some(wrappedValue)
        }
        return .none
    }
}

extension Array: AttributeType, VProtocol where Element: AttributeType {

    public static var typeName: String {
        return "[" + Element.typeName + "]"
    }

    public static func fromString(_ string: String) throws(VError) -> Self {
        var trimmed = string.trimmingCharacters(in: " \t\n\r")
        guard trimmed.hasPrefix("[") && trimmed.hasSuffix("]") else {
            throw .conversionError(from: string, to: "Array of \(Element.typeName)")
        }
        trimmed.removeFirst()
        trimmed.removeLast()
        let elementsString = trimmed.split(separator: ",").map { $0.trimmingCharacters(in: " \t\n\r") }
        let elements: [Element] = try elementsString.map(Element.fromString)
        return elements
    }

    public var asString: String {
        return "[" + self.map { $0.asString }.joined(separator: ",") + "]"
    }

}
