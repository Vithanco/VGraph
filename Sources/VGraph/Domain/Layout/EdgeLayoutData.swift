public struct ArrowHeadData: VProtocol {
    public let shape: Shape
    public let color: String

    public init(shape: Shape, color: String) {
        self.shape = shape
        self.color = color
    }
}

public struct LabelData: VProtocol {
    public let text: String
    public let position: VPoint
    public let fontSize: Double?
    public let fontFamily: String?

    public init(text: String, position: VPoint, fontSize: Double? = nil, fontFamily: String? = nil) {
        self.text = text
        self.position = position
        self.fontSize = fontSize
        self.fontFamily = fontFamily
    }
}

public struct EdgeLayoutData: AttributeType {
    /// B-spline control points defining the edge curve
    /// Format: 3n+1 points where point[0] is start, then groups of 3 for cubic Bezier curves
    public let splinePoints: [VPoint]
    public let arrowHead: ArrowHeadData?
    public let arrowTail: ArrowHeadData?
    public let color: String?
    public let style: String?
    public let penwidth: Double?
    public let label: LabelData?
    public let headLabel: LabelData?
    public let tailLabel: LabelData?

    public init(
        splinePoints: [VPoint],
        arrowHead: ArrowHeadData? = nil,
        arrowTail: ArrowHeadData? = nil,
        color: String? = nil,
        style: String? = nil,
        penwidth: Double? = nil,
        label: LabelData? = nil,
        headLabel: LabelData? = nil,
        tailLabel: LabelData? = nil
    ) {
        self.splinePoints = splinePoints
        self.arrowHead = arrowHead
        self.arrowTail = arrowTail
        self.color = color
        self.style = style
        self.penwidth = penwidth
        self.label = label
        self.headLabel = headLabel
        self.tailLabel = tailLabel
    }

    // MARK: - AttributeType conformance

    public static var typeName: String { "EdgeLayoutData" }

    public var asString: String {
        var fields = ["\"splinePoints\":[" + splinePoints.map { LayoutDataText.point($0) }.joined(separator: ",") + "]"]
        if let arrowHead { fields.append("\"arrowHead\":" + Self.text(of: arrowHead)) }
        if let arrowTail { fields.append("\"arrowTail\":" + Self.text(of: arrowTail)) }
        if let color { fields.append("\"color\":" + LayoutDataText.quoted(color)) }
        if let style { fields.append("\"style\":" + LayoutDataText.quoted(style)) }
        if let penwidth { fields.append("\"penwidth\":\(penwidth)") }
        if let label { fields.append("\"label\":" + Self.text(of: label)) }
        if let headLabel { fields.append("\"headLabel\":" + Self.text(of: headLabel)) }
        if let tailLabel { fields.append("\"tailLabel\":" + Self.text(of: tailLabel)) }
        return "{" + fields.joined(separator: ",") + "}"
    }

    public static func fromString(_ string: String) throws(VError) -> EdgeLayoutData {
        let splinePoints = splinePoints(in: string)
        guard !splinePoints.isEmpty else {
            throw VError.parsingError("EdgeLayoutData: missing or empty splinePoints field")
        }
        return EdgeLayoutData(
            splinePoints: splinePoints,
            arrowHead: arrow("arrowHead", in: string),
            arrowTail: arrow("arrowTail", in: string),
            color: LayoutDataText.string("color", in: outsideArrows(string)),
            style: LayoutDataText.string("style", in: string),
            penwidth: LayoutDataText.double("penwidth", in: string),
            label: label("label", in: string),
            headLabel: label("headLabel", in: string),
            tailLabel: label("tailLabel", in: string)
        )
    }

    private static func text(of arrow: ArrowHeadData) -> String {
        "{\"shape\":\(arrow.shape.asString),\"color\":\(LayoutDataText.quoted(arrow.color))}"
    }

    private static func text(of label: LabelData) -> String {
        var fields = ["\"text\":" + LayoutDataText.quoted(label.text), "\"position\":" + LayoutDataText.point(label.position)]
        if let fontSize = label.fontSize { fields.append("\"fontSize\":\(fontSize)") }
        if let fontFamily = label.fontFamily { fields.append("\"fontFamily\":" + LayoutDataText.quoted(fontFamily)) }
        return "{" + fields.joined(separator: ",") + "}"
    }

    private static func splinePoints(in string: String) -> [VPoint] {
        guard let start = string.range(of: "\"splinePoints\":["),
            let end = string[start.upperBound...].firstIndex(of: "]")
        else { return [] }
        return LayoutDataText.points(in: String(string[start.upperBound..<end]))
    }

    private static func arrow(_ key: String, in string: String) -> ArrowHeadData? {
        guard let body = LayoutDataText.object(key, in: string).map({ String($0) }),
            let color = LayoutDataText.string("color", in: body),
            let shapeBody = LayoutDataText.object("shape", in: body),
            let shape = try? Shape.fromString("{" + shapeBody + "}")
        else { return nil }
        return ArrowHeadData(shape: shape, color: color)
    }

    /// The edge's own fields: an arrow carries a `color` of its own.
    private static func outsideArrows(_ string: String) -> String {
        var remaining = string
        for key in ["arrowHead", "arrowTail"] {
            if let body = LayoutDataText.objectRange(key, in: remaining) { remaining.removeSubrange(body) }
        }
        return remaining
    }

    private static func label(_ key: String, in string: String) -> LabelData? {
        guard let body = LayoutDataText.object(key, in: string).map({ String($0) }),
            let text = LayoutDataText.string("text", in: body),
            let position = LayoutDataText.object("position", in: body).map({ String($0) }),
            let x = LayoutDataText.double("x", in: position),
            let y = LayoutDataText.double("y", in: position)
        else { return nil }
        return LabelData(
            text: text, position: VPoint(x: x, y: y), fontSize: LayoutDataText.double("fontSize", in: body),
            fontFamily: LayoutDataText.string("fontFamily", in: body))
    }
}
