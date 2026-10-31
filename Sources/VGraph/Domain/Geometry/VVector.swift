import MathUtils

//https://github.com/raywenderlich/SKTUtils/blob/master/SKTUtils/VVector%2BExtensions.swift
public struct VVector: VProtocol {

    public init() {
        dx = 0.0
        dy = 0.0
    }

    public init(dx: Double, dy: Double) {
        self.dx = dx
        self.dy = dy
    }

    public let dx: Double

    public let dy: Double
}

extension VVector {
    public init(point: VPoint) {
        self.init(dx: point.x, dy: point.y)
    }

    public init(from: VPoint, to: VPoint) {
        self.init(dx: to.x - from.x, dy: to.y - from.y)
    }

    public var orthogonalVector: VVector {
        return VVector(dx: self.dy, dy: self.dx * -1.0)
    }

    public var opposingVector: VVector {
        return VVector(dx: -1.0 * self.dx, dy: -1.0 * self.dy)
    }

    /// Given an angle in radians, creates a vector of length 1.0 and returns the
    /// result as a new VVector. An angle of 0 is assumed to point to the right.
    public init(angle: Double) {
        self.init(dx: Math.cos(angle), dy: Math.sin(angle))
    }

    public static let zero: VVector = VVector(dx: 0.0, dy: 0.0)

    public func offset(dx: Double, dy: Double) -> VVector {
        return VVector(dx: self.dx + dx, dy: self.dy + dy)
    }

    public func length() -> Double {
        return (dx * dx + dy * dy).squareRoot()
    }

    public func lengthSquared() -> Double {
        return dx * dx + dy * dy
    }

    public func normalized() -> VVector {
        let len = length()
        return len > 0 ? self / len : VVector.zero
    }

    public func distanceTo(_ vector: VVector) -> Double {
        return (self - vector).length()
    }

    /// Returns the angle in radians of the vector described by the VVector.
    /// The range of the angle is -π to π; an angle of 0 points to the right.
    public var angle: Double {
        return Math.atan2(dy, dx)
    }

    public func angleBetween(other: VVector) -> Double {
        let diff = self - other
        return diff.angle
    }

    public func turn(degree: Double) -> VVector {
        let sinus = Math.sin(degree)
        let cosinus = Math.cos(degree)
        let x2 = cosinus * self.dx - sinus * self.dy
        let y2 = sinus * self.dx + cosinus * self.dy
        return VVector(dx: x2, dy: y2)
    }
}

public func + (left: VVector, right: VVector) -> VVector {
    return VVector(dx: left.dx + right.dx, dy: left.dy + right.dy)
}

public func += (left: inout VVector, right: VVector) {
    left = left + right
}

public func - (left: VVector, right: VVector) -> VVector {
    return VVector(dx: left.dx - right.dx, dy: left.dy - right.dy)
}

public func -= (left: inout VVector, right: VVector) {
    left = left - right
}

public func * (left: VVector, right: VVector) -> VVector {
    return VVector(dx: left.dx * right.dx, dy: left.dy * right.dy)
}

public func *= (left: inout VVector, right: VVector) {
    left = left * right
}

public func * (vector: VVector, scalar: Double) -> VVector {
    return VVector(dx: vector.dx * scalar, dy: vector.dy * scalar)
}

public func *= (vector: inout VVector, scalar: Double) {
    vector = vector * scalar
}

public func / (left: VVector, right: VVector) -> VVector {
    return VVector(dx: left.dx / right.dx, dy: left.dy / right.dy)
}

public func /= (left: inout VVector, right: VVector) {
    left = left / right
}

public func / (vector: VVector, scalar: Double) -> VVector {
    return VVector(dx: vector.dx / scalar, dy: vector.dy / scalar)
}

public func /= (vector: inout VVector, scalar: Double) {
    vector = vector / scalar
}

public func lerp(start: VVector, end: VVector, t: Double) -> VVector {
    return start + (end - start) * t
}
