public protocol AttributeType: VProtocol {
    static var typeName: String { get }
    static func fromString(_ string: String) throws(VError) -> Self
    var asString: String { get }
}

public protocol EnumAttributeType: HasReadableNames {
}
