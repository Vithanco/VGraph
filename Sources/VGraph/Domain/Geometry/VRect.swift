public struct VRect: VProtocol {
    public let origin: VPoint
    public let size: VSize

    public init(origin: VPoint, size: VSize) {
        self.origin = origin
        self.size = size
    }
}

extension VRect {
    public var x: Double { return self.origin.x }
    public var y: Double { return self.origin.y }
    public var width: Double { return self.size.width }
    public var height: Double { return self.size.height }
    public var minX: Double { return self.x }
    public var maxX: Double { return self.x + self.width }
    public var minY: Double { return self.y }
    public var maxY: Double { return self.y + self.height }

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.init(origin: VPoint(x: x, y: y), size: VSize(width: width, height: height))
    }

    public init(minX: Double, minY: Double, maxX: Double, maxY: Double) {
        self.init(origin: VPoint(x: minX, y: minY), size: VSize(width: maxX - minX, height: maxY - minY))
    }

    public static let zero = VRect(origin: .zero, size: .zero)
}

extension VRect: AttributeType {
    public static var typeName: String {
        return "VRect"
    }

    /// `x,y,width,height`.
    public static func fromString(_ string: String) throws(VError) -> VRect {
        guard let numbers = commaSeparatedNumbers(string, count: 4) else {
            throw VError.conversionError(from: string, to: Self.typeName)
        }
        return VRect(x: numbers[0], y: numbers[1], width: numbers[2], height: numbers[3])
    }

    public var asString: String {
        return "\(origin.x),\(origin.y),\(size.width),\(size.height)"
    }
}
