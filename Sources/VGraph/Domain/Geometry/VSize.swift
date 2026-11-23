public struct VSize: VProtocol {
    public let width: Double
    public let height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }

    public static let zero = VSize(width: 0, height: 0)
}

extension VSize {
    public func widthAtLeast(_ minWidth: Double) -> VSize {
        if minWidth > self.width {
            return VSize(width: minWidth, height: self.height)
        }
        return self
    }
}

extension VSize: AttributeType {
    public static func fromString(_ string: String) throws(VError) -> VSize {
        guard let numbers = commaSeparatedNumbers(string, count: 2) else {
            throw VError.conversionError(from: string, to: Self.typeName)
        }
        return VSize(width: numbers[0], height: numbers[1])
    }

    public static var typeName: String {
        return "VSize"
    }

    public var asString: String {
        return "\(width),\(height)"
    }
}
