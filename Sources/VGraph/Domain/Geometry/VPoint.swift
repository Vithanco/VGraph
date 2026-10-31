public struct VPoint: VProtocol {

    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

extension VPoint: CustomStringConvertible {
    public var description: String {
        return asString
    }
}

extension VPoint: AttributeType {

    enum AttributeParsingError: Error {
        case invalidFormat
    }

    public static func fromString(_ string: String) throws(VError) -> VPoint {
        let components = string.split(separator: ",")
        guard components.count == 2,
            let x = Double(String(components[0])),
            let y = Double(String(components[1]))
        else {
            throw VError.conversionError(from: string, to: Self.typeName)
        }
        return VPoint(x: x, y: y)
    }

    public static var typeName: String {
        return "VPoint"
    }

    public var asString: String {
        return "\(x),\(y)"
    }
}

let nilPoint: VPoint? = Optional<VPoint>.none

extension VPoint: Sendable {

    public func hash(into hasher: inout Hasher) {
        hasher.combine(x)
        hasher.combine(y)
    }

    public static func == (lhs: VPoint, rhs: VPoint) -> Bool {
        return lhs.x == rhs.x && lhs.y == rhs.y
    }

    public static func toString(_ value: VPoint) -> String {
        return value.asString
    }
}

extension VPoint {
    public func shift(_ x: Double, _ y: Double) -> VPoint {
        return VPoint(x: self.x + x, y: self.y + y)
    }

    public func shift(_ dir: VVector) -> VPoint {
        return VPoint(x: self.x + dir.dx, y: self.y + dir.dy)
    }

    public func substract(_ dir: VPoint) -> VPoint {
        return VPoint(x: self.x - dir.x, y: self.y - dir.y)
    }

    public var flipped: VPoint {
        return VPoint(x: self.y, y: self.x)
    }

    public func interpolate(to: VPoint, distance: Double) -> VPoint {
        let x = Double(1 - distance) * self.x + Double(distance) * to.x
        let y = Double(1 - distance) * self.y + Double(distance) * to.y
        return VPoint(x: x, y: y)
    }

    public func interpolateAndOrthoVector(to: VPoint, distance: Double) -> (VPoint, VVector) {
        let x = Double(1 - distance) * self.x + Double(distance) * to.x
        let y = Double(1 - distance) * self.y + Double(distance) * to.y
        return (VPoint(x: x, y: y), VVector(from: self, to: to).orthogonalVector)  //.normalized())
    }

    public func distance(to: VPoint) -> Double {
        let xDist: Double = to.x - self.x
        let yDist: Double = to.y - self.y
        return (xDist * xDist + yDist * yDist).squareRoot()
    }

    public var isFinite: Bool {
        return x.isFinite && y.isFinite
    }

    public var makeNegative: VPoint {
        return VPoint(x: -1.0 * self.x, y: -1.0 * self.y)
    }
    public var asVector: VVector {
        return VVector(dx: x, dy: y)
    }

    public func orderByDistance(set: Set<VPoint>) -> [VPoint] {
        return self.orderByDistance(points: set.asArray)
    }

    public func orderByDistance(points: [VPoint]) -> [VPoint] {
        return points.sorted(by: { a, b in return self.distance(to: a) > self.distance(to: b) })
    }

    public func orderByDistance(_ a: VPoint, _ b: VPoint) -> (VPoint, VPoint) {
        return self.distance(to: a) > self.distance(to: b) ? (b, a) : (a, b)
    }

    public static func / (left: VPoint, right: Double) -> VPoint {
        return VPoint(x: left.x / right, y: left.y / right)
    }

    public static func / (left: VPoint, right: Int) -> VPoint {
        return left / Double(right)
    }

    public func convertZeroPointToNil(precision: Double = 0.1) -> VPoint? {
        if self.distance(to: .zero) < precision {
            return nil
        }
        return self
    }

    public static let zero = VPoint(x: 0, y: 0)

    public var rounded: VPoint {
        return VPoint(x: self.x.rounded(), y: self.y.rounded())
    }

}

public func + (left: VPoint, right: VPoint) -> VPoint {
    return VPoint(x: left.x + right.x, y: left.y + right.y)
}

public func - (left: VPoint, right: VPoint) -> VPoint {
    return VPoint(x: left.x - right.x, y: left.y - right.y)
}

public func + (left: VPoint, right: VVector) -> VPoint {
    return VPoint(x: left.x + right.dx, y: left.y + right.dy)
}

func convertZeroPointToNil(_ gvPos: VPoint, precision: Double = 0.1) -> VPoint? {
    return gvPos.convertZeroPointToNil(precision: precision)
}

public func midPoint(between: VPoint, and: VPoint) -> VPoint {
    return (between + and) / 2
}
