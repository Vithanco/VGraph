public enum NodeBackground: VProtocol {
    case appearance(shape: NodeShape, color: SemanticColor)
    case solid(shape: NodeShape, color: SemanticColor)
    case clear(shape: NodeShape)
    /// Pill background — fully rounded ends (rx = height/2), used for ghost nodes.
    case pill(color: SemanticColor)

    // MARK: - Shape Accessor

    public var shape: NodeShape {
        switch self {
        case .appearance(let shape, _): return shape
        case .solid(let shape, _): return shape
        case .clear(let shape): return shape
        case .pill: return .box
        }
    }

    // MARK: - Serialization

    public static func fromString(_ string: String) throws(VError) -> NodeBackground {
        // Legacy format support (no shape specified, defaults to box)
        if string == "clear" {
            return .clear(shape: .box)
        }
        if string.hasPrefix("a{") && string.hasSuffix("}") {
            let content = String(string.dropFirst(2).dropLast())
            guard let pipeIndex = content.firstIndex(of: "|") else {
                // Legacy format: just color, default to box
                let color = try SemanticColor.fromString(content)
                return .appearance(shape: .box, color: color)
            }
            let shapeStr = String(content[..<pipeIndex])
            let colorStr = String(content[content.index(after: pipeIndex)...])
            let shape = try NodeShape.fromString(shapeStr)
            let color = try SemanticColor.fromString(colorStr)
            return .appearance(shape: shape, color: color)
        }
        if string.hasPrefix("s{") && string.hasSuffix("}") {
            let content = String(string.dropFirst(2).dropLast())
            guard let pipeIndex = content.firstIndex(of: "|") else {
                // Legacy format: just color, default to box
                let color = try SemanticColor.fromString(content)
                return .solid(shape: .box, color: color)
            }
            let shapeStr = String(content[..<pipeIndex])
            let colorStr = String(content[content.index(after: pipeIndex)...])
            let shape = try NodeShape.fromString(shapeStr)
            let color = try SemanticColor.fromString(colorStr)
            return .solid(shape: shape, color: color)
        }
        if string.hasPrefix("clear{") && string.hasSuffix("}") {
            let shapeStr = String(string.dropFirst(6).dropLast())
            let shape = try NodeShape.fromString(shapeStr)
            return .clear(shape: shape)
        }
        if string.hasPrefix("pill{") && string.hasSuffix("}") {
            let colorStr = String(string.dropFirst(5).dropLast())
            let color = try SemanticColor.fromString(colorStr)
            return .pill(color: color)
        }
        throw VError.conversionError(from: string, to: "NodeBackground")
    }

    public var asString: String {
        switch self {
        case .appearance(let shape, let color):
            return "a{\(shape.asString)|\(color.asString)}"
        case .solid(let shape, let color):
            return "s{\(shape.asString)|\(color.asString)}"
        case .clear(let shape):
            return "clear{\(shape.asString)}"
        case .pill(let color):
            return "pill{\(color.asString)}"
        }
    }
}
