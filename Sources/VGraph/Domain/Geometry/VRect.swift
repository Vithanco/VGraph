public enum VerticalPosition {
    case top
    case middle
    case bottom
}

public enum HorizontalPosition {
    case left
    case oneQuarter
    case middle
    case threeQuarters
    case right
}

public enum ZeroPos {
    case topLeft
    case bottomLeft
}

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

    public var midPoint: VPoint {
        return self.position(.middle, horizontal: .middle)
    }

    public init(midPoint: VPoint, size: VSize) {
        self.init(
            x: midPoint.x - size.width / 2, y: midPoint.y - size.height / 2, width: size.width, height: size.height)
    }

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.init(origin: VPoint(x: x, y: y), size: VSize(width: width, height: height))
    }

    public init(minX: Double, minY: Double, maxX: Double, maxY: Double) {
        self.init(origin: VPoint(x: minX, y: minY), size: VSize(width: maxX - minX, height: maxY - minY))
    }

    public static let zero = VRect(origin: .zero, size: .zero)

    public func subRect(_ border: Double) -> VRect {
        return VRect(
            x: self.origin.x + border, y: self.origin.y + border, width: self.width - 2 * border,
            height: self.height - 2 * border)
    }

    public func subRect(inMiddle: VRect) -> VRect {
        return self.subRect(inMiddleSize: inMiddle.size)
    }

    public func subRect(fromTop: Double, cSpace: ZeroPos) -> VRect {
        guard cSpace == .topLeft else {
            fatalError("needs implementation")
        }
        return VRect(origin: self.origin, size: VSize(width: self.width, height: fromTop))
    }

    public func subRect(inMiddleSize: VSize) -> VRect {
        return VRect(midPoint: self.midPoint, size: inMiddleSize)
    }

    public func subRect(factor: Double) -> VRect {
        assert(factor >= 0)
        assert(factor <= 1)
        return self.subRect(inMiddleSize: self.size * factor)
    }

    public func expandRect(_ border: Double) -> VRect {
        return self.subRect(-1 * border)
    }

    public func moveMiddleTo(_ point: VPoint) -> VRect {
        return VRect(midPoint: point, size: self.size)
    }

    public func position(_ vertical: VerticalPosition, horizontal: HorizontalPosition) -> VPoint {
        var x: Double
        var y: Double
        switch vertical {
        case .top:
            y = self.origin.y + self.height
        case .middle:
            y = self.origin.y + self.height * 0.5
        case .bottom:
            y = self.origin.y
        }
        switch horizontal {
        case .left:
            x = self.origin.x
        case .middle:
            x = self.origin.x + self.width * 0.5
        case .right:
            x = self.origin.x + self.width
        case .oneQuarter:
            x = self.origin.x + self.width * 0.25
        case .threeQuarters:
            x = self.origin.x + self.width * 0.75
        }
        return VPoint(x: x, y: y)
    }

    public func innerPosition(horizontal: HorizontalPosition, vertical: VerticalPosition, distance: Double) -> VPoint {
        var x: Double
        var y: Double
        switch vertical {
        case .top:
            y = self.origin.y + self.height - distance
        case .middle:
            y = self.origin.y + self.height * 0.5
        case .bottom:
            y = self.origin.y + distance
        }
        switch horizontal {
        case .left:
            x = self.origin.x + distance
        case .middle:
            x = self.origin.x + self.width * 0.5
        case .right:
            x = self.origin.x + self.width - distance
        case .oneQuarter:
            x = self.origin.x + (self.width - distance) * 0.25
        case .threeQuarters:
            x = self.origin.x + (self.width - distance) * 0.75
        }
        return VPoint(x: x, y: y)
    }

    public func outerPosition(horizontal: HorizontalPosition, vertical: VerticalPosition, distance: VVector) -> VPoint {
        var x: Double
        var y: Double
        switch vertical {
        case .top:
            y = self.origin.y + self.height + distance.dy
        case .middle:
            y = self.origin.y + self.height * 0.5
        case .bottom:
            y = self.origin.y - distance.dy
        }
        switch horizontal {
        case .left:
            x = self.origin.x - distance.dx
        case .middle:
            x = self.origin.x + self.width * 0.5
        case .right:
            x = self.origin.x + self.width + distance.dx
        case .oneQuarter:
            x = self.origin.x + (self.width + distance.dx) * 0.25
        case .threeQuarters:
            x = self.origin.x + (self.width + distance.dx) * 0.75
        }
        return VPoint(x: x, y: y)
    }

    public var top: Double {
        return self.origin.y + self.height
    }

    public var right: Double {
        return self.origin.x + self.width
    }

    public var rounded: VRect {
        return VRect(origin: self.origin.rounded, size: self.size.rounded)
    }

    public func addToHeight(_ amount: Double) -> VRect {
        return VRect(x: self.origin.x, y: self.origin.y, width: self.size.width, height: self.size.height + amount)
    }

    public func addToWidth(_ amount: Double) -> VRect {
        return VRect(x: self.origin.x, y: self.origin.y, width: self.size.width + amount, height: self.size.height)
    }

    public func substractFromHeight(_ amount: Double) -> VRect {
        return self.addToHeight(-1 * amount)
    }

    /// create a rect that is determined by two opposing corners
    public init(point1: VPoint, point2: VPoint) {
        self.init(
            x: min(point1.x, point2.x), y: min(point1.y, point2.y), width: abs(point1.x - point2.x),
            height: abs(point1.y - point2.y))
    }

    public func combine(_ other: VRect) -> VRect {
        return VRect(
            minX: min(self.minX, other.minX),
            minY: min(self.minY, other.minY),
            maxX: max(self.maxX, other.maxX),
            maxY: max(self.maxY, other.maxY)
        )
    }

    public func offsetBy(dx: Double, dy: Double) -> VRect {
        return VRect(x: self.origin.x + dx, y: self.origin.y + dy, width: self.size.width, height: self.size.height)
    }

    public func shift(by: VVector) -> VRect {
        return self.offsetBy(dx: by.dx, dy: by.dy)
    }

    public func shift(dx: Double, dy: Double) -> VRect {
        return self.offsetBy(dx: dx, dy: dy)
    }

    public func minSized(_ minSize: VSize) -> VRect {
        return self.minSized(width: minSize.width, height: minSize.height)
    }

    public func minSized(width: Double, height: Double) -> VRect {
        return VRect(
            midPoint: self.midPoint, size: VSize(width: max(width, self.width), height: max(height, self.height)))
    }

    public func enlarge(width: Double, height: Double) -> VRect {
        return VRect(midPoint: self.midPoint, size: VSize(width: self.width + width, height: self.height + height))
    }

    public func contains(_ point: VPoint) -> Bool {
        return point.x >= minX && point.x <= maxX && point.y >= minY && point.y <= maxY
    }
}

extension VRect: AttributeType {
    public static var typeName: String {
        return "VRect"
    }

    public static func fromString(_ string: String) throws(VError) -> VRect {
        // Format: "x,y,width,height"
        let components = string.split(separator: ",")
        guard components.count == 4,
            let x = Double(String(components[0])),
            let y = Double(String(components[1])),
            let width = Double(String(components[2])),
            let height = Double(String(components[3]))
        else {
            throw VError.conversionError(from: string, to: Self.typeName)
        }
        return VRect(x: x, y: y, width: width, height: height)
    }

    public var asString: String {
        return "\(origin.x),\(origin.y),\(size.width),\(size.height)"
    }
}
