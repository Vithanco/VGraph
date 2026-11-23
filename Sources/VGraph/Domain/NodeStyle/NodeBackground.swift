public enum NodeBackground: VProtocol {
    case appearance(shape: NodeShape, color: SemanticColor)
    case solid(shape: NodeShape, color: SemanticColor)
    case clear(shape: NodeShape)
    /// Pill background — fully rounded ends (rx = height/2), used for ghost nodes.
    case pill(color: SemanticColor)

    public var shape: NodeShape {
        switch self {
        case .appearance(let shape, _): return shape
        case .solid(let shape, _): return shape
        case .clear(let shape): return shape
        case .pill: return .box
        }
    }

    public static func fromString(_ string: String) throws(VError) -> NodeBackground {
        // Written before a background carried a shape; it was a box.
        if string == "clear" {
            return .clear(shape: .box)
        }
        if let content = body(of: string, tag: "a") {
            let (shape, color) = try shapeAndColor(content)
            return .appearance(shape: shape, color: color)
        }
        if let content = body(of: string, tag: "s") {
            let (shape, color) = try shapeAndColor(content)
            return .solid(shape: shape, color: color)
        }
        if let content = body(of: string, tag: "clear") {
            return .clear(shape: try NodeShape.fromString(content))
        }
        if let content = body(of: string, tag: "pill") {
            return .pill(color: try SemanticColor.fromString(content))
        }
        throw VError.conversionError(from: string, to: "NodeBackground")
    }

    /// The text between `tag{` and the closing `}`, or nil when `string` is not that tag.
    private static func body(of string: String, tag: String) -> String? {
        guard string.hasPrefix(tag + "{"), string.hasSuffix("}") else { return nil }
        return String(string.dropFirst(tag.count + 1).dropLast())
    }

    /// `shape|colour`, or a bare colour written before a background carried a shape.
    private static func shapeAndColor(_ content: String) throws(VError) -> (NodeShape, SemanticColor) {
        guard let pipe = content.firstIndex(of: "|") else {
            return (.box, try SemanticColor.fromString(content))
        }
        let shape = try NodeShape.fromString(String(content[..<pipe]))
        let color = try SemanticColor.fromString(String(content[content.index(after: pipe)...]))
        return (shape, color)
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
