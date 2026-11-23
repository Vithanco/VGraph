public struct VPoint: VProtocol {

    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public static let zero = VPoint(x: 0, y: 0)

    public static func - (left: VPoint, right: VPoint) -> VPoint {
        VPoint(x: left.x - right.x, y: left.y - right.y)
    }
}

extension VPoint: CustomStringConvertible {
    public var description: String {
        return asString
    }
}

extension VPoint: AttributeType {

    public static func fromString(_ string: String) throws(VError) -> VPoint {
        guard let numbers = commaSeparatedNumbers(string, count: 2) else {
            throw VError.conversionError(from: string, to: Self.typeName)
        }
        return VPoint(x: numbers[0], y: numbers[1])
    }

    public static var typeName: String {
        return "VPoint"
    }

    public var asString: String {
        return "\(x),\(y)"
    }
}
