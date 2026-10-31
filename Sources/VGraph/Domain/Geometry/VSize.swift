import MathUtils

public struct VSize: VProtocol {
    public let width: Double
    public let height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

extension VSize {
    public init(quadrat: Double) {
        self.init(width: quadrat, height: quadrat)
    }

    // assuming you have a field a by b and you create an additional border of 5 meters around, then you have a 10 meters bigger field, in both dimentions.
    public func addBorderTwice(_ amount: Double) -> VSize {
        return self.expand(by: 2 * amount)
    }

    public func addToHeight(_ amount: Double) -> VSize {
        return VSize(width: self.width, height: self.height + amount)
    }

    public func addToWidth(_ amount: Double) -> VSize {
        return VSize(width: self.width + amount, height: self.height)
    }

    public func removeFromWidth(_ amount: Double) -> VSize {
        return VSize(width: self.width - amount, height: self.height)
    }

    public func substract(_ amount: VSize) -> VSize {
        return VSize(width: self.width - amount.width, height: self.height - amount.height)
    }

    public func substract(_ amount: Double) -> VSize {
        return VSize(width: self.width - amount, height: self.height - amount)
    }

    public func widthAtLeast(_ minWidth: Double) -> VSize {
        if minWidth > self.width {
            return VSize(width: minWidth, height: self.height)
        }
        return self
    }

    public func heightAtLeast(_ minHeight: Double) -> VSize {
        if minHeight > self.height {
            return VSize(width: self.width, height: minHeight)
        }
        return self
    }

    public func atLeast(size: VSize) -> VSize {
        return VSize(width: max(size.width, self.width), height: max(size.height, self.height))
    }

    public func atMost(size: VSize) -> VSize {
        return VSize(width: min(size.width, self.width), height: min(size.height, self.height))
    }

    public func ceil() -> VSize {
        return VSize(width: self.width.ceiled, height: self.height.ceiled)
    }

    public var area: Double {
        return self.width * self.height
    }

    public func expand(by increment: Double) -> VSize {
        return VSize(width: self.width + increment, height: self.height + increment)
    }

    public func add(width: Double = 0, height: Double = 0) -> VSize {
        return VSize(width: self.width + width, height: self.height + height)
    }

    public func minimumSize(width: Double = 0, height: Double = 0) -> VSize {
        return VSize(width: max(self.width, width), height: max(self.height, height))
    }

    public func expand(bySize: VSize) -> VSize {
        return VSize(width: self.width + bySize.width, height: self.height + bySize.height)
    }

    public func smallerThan(_ other: VSize) -> Bool {
        return self.width < other.width && self.height < other.height
    }

    public func biggerThan(_ other: VSize) -> Bool {
        return self.width > other.width && self.height > other.height
    }

    public var smallerSide: Double {
        return width < height ? width : height
    }

    public var biggerSide: Double {
        return width > height ? width : height
    }

    public static func * (left: VSize, factor: Double) -> VSize {
        return VSize(width: left.width * factor, height: left.height * factor)
    }

    public static func / (left: VSize, factor: Double) -> VSize {
        return VSize(width: left.width * factor, height: left.height / factor)
    }

    public static func >= (left: VSize, right: VSize) -> Bool {
        return left.width >= right.width && left.height >= right.height
    }

    public static func <= (left: VSize, right: VSize) -> Bool {
        return right >= left
    }

    public static func + (left: VSize, right: VEdgeInsets) -> VSize {
        return VSize(
            width: left.width + right.left + right.right,
            height: left.height + right.top + right.bottom)
    }

    public static func - (lhs: VSize, rhs: VEdgeInsets) -> VSize {
        let width = (lhs.width - rhs.left) - rhs.right
        let height = (lhs.height - rhs.top) - rhs.bottom
        return VSize(width: width, height: height)
    }

    public var diagonalLength: Double {
        return (width * width + height * height).squareRoot()
    }

    public var midPoint: VPoint {
        return VPoint(x: width / 2.0, y: height / 2.0)
    }

    public static func - (left: VSize, right: VSize) -> VVector {
        return VVector(dx: left.width - right.width, dy: left.height - right.height)
    }

    public static func - (left: VSize, right: Double) -> VSize {
        return VSize(width: left.width - right, height: left.height - right)
    }

    public func centerWithin(_ bigger: VRect) -> VRect {
        let diff = (bigger.size - self) / 2.0
        return VRect(origin: VPoint(x: diff.dx, y: diff.dy), size: self)
    }

    public var rounded: VSize {
        return VSize(width: self.width.rounded(), height: self.height.rounded())
    }
}

public func maxForEachDimension(_ left: VSize, _ right: VSize) -> VSize {
    return VSize(width: max(left.width, right.width), height: max(left.height, right.height))
}

public func minForEachDimension(_ left: VSize, _ right: VSize) -> VSize {
    return VSize(width: min(left.width, right.width), height: min(left.height, right.height))
}

extension VSize: AttributeType {
    enum AttributeParsingError: Error {
        case invalidFormat
    }

    public static func fromString(_ string: String) throws(VError) -> VSize {
        let components = string.split(separator: ",")
        guard components.count == 2,
            let width = Double(String(components[0])),
            let height = Double(String(components[1]))
        else {
            throw VError.conversionError(from: string, to: Self.typeName)
        }
        return VSize(width: width, height: height)
    }

    public static var typeName: String {
        return "VSize"
    }

    public static func == (lhs: VSize, rhs: VSize) -> Bool {
        return lhs.width == rhs.width && lhs.height == rhs.height
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.width)
        hasher.combine(self.height)
    }

    public var asString: String {
        return "\(width),\(height)"
    }

    public static let zero = VSize(width: 0, height: 0)
}
