public struct VEdgeInsets: VProtocol {
    public let top: Double
    public let left: Double
    public let bottom: Double
    public let right: Double

    public init(top: Double = 0.0, left: Double = 0.0, bottom: Double = 0.0, right: Double = 0.0) {
        self.top = top
        self.left = left
        self.bottom = bottom
        self.right = right
    }

    /// The same inset on all four sides.
    public init(regular: Double) {
        self.init(top: regular, left: regular, bottom: regular, right: regular)
    }

    public static let zero = VEdgeInsets()
}

extension VEdgeInsets: AttributeType {
    public static var typeName: String {
        return "VEdgeInsets"
    }

    public static func fromString(_ string: String) throws(VError) -> VEdgeInsets {
        guard let numbers = commaSeparatedNumbers(string, count: 4) else {
            throw VError.conversionError(from: string, to: typeName)
        }
        return VEdgeInsets(top: numbers[0], left: numbers[1], bottom: numbers[2], right: numbers[3])
    }

    public var asString: String {
        [top, left, bottom, right].map { $0.asString(decimals: 2) }.joined(separator: ",")
    }
}
