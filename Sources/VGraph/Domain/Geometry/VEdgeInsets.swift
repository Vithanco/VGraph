public struct VEdgeInsets: VProtocol {
    public var top: Double
    public var left: Double
    public var bottom: Double
    public var right: Double

    public init() {
        self.top = 0
        self.left = 0
        self.bottom = 0
        self.right = 0
    }

    public init(top: Double = 0.0, left: Double = 0.0, bottom: Double = 0.0, right: Double = 0.0) {
        self.top = top
        self.left = left
        self.bottom = bottom
        self.right = right
    }

    public static let zero: VEdgeInsets = .init()

    public var leading: Double {
        return left
    }
}

extension VEdgeInsets {
    public static func + (left: VEdgeInsets, right: VEdgeInsets) -> VEdgeInsets {
        return VEdgeInsets(
            top: left.top + right.top, left: left.left + right.left, bottom: left.bottom + right.bottom,
            right: left.right + right.right)
    }

    public init(regular: Double) {
        self.init(top: regular, left: regular, bottom: regular, right: regular)
    }

    public func substractFromTop(_ amount: Double) -> VEdgeInsets {
        return VEdgeInsets(top: self.top + amount, left: self.left, bottom: self.bottom, right: self.right)
    }

    public func addToLeft(_ amount: Double) -> VEdgeInsets {
        return VEdgeInsets(top: self.top, left: self.left + amount, bottom: self.bottom, right: self.right)
    }
}

extension VEdgeInsets: AttributeType {
    public static var typeName: String {
        return "VEdgeInsets"
    }

    public static func fromString(_ string: String) throws(VError) -> VEdgeInsets {
        let parts = string.split(separator: ",").map(String.init)
        guard parts.count == 4 else {
            throw VError.conversionError(from: string, to: typeName)
        }
        guard let top = Double(parts[0]),
            let left = Double(parts[1]),
            let bottom = Double(parts[2]),
            let right = Double(parts[3])
        else {
            throw VError.conversionError(from: string, to: typeName)
        }
        return VEdgeInsets(top: top, left: left, bottom: bottom, right: right)
    }

    public var asString: String {
        return
            "\(top.asString(decimals: 2)),\(left.asString(decimals: 2)),\(bottom.asString(decimals: 2)),\(right.asString(decimals: 2))"
    }
}
