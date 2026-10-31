public struct ArrowHeadData: VProtocol {
    public let shape: Shape
    public let color: String

    public init(shape: Shape, color: String) {
        self.shape = shape
        self.color = color
    }

    // Backward compatibility: access polygon points
    public var polygonPoints: [VPoint] {
        return shape.toPolygonPoints()
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
        // Manual JSON-like encoding to avoid JSONEncoder (not available in WASM)
        var result = "{\"splinePoints\":["
        for (index, point) in splinePoints.enumerated() {
            if index > 0 { result += "," }
            result += "{\"x\":\(point.x),\"y\":\(point.y)}"
        }
        result += "]"

        if let arrowHead = arrowHead {
            result += ",\"arrowHead\":{\"shape\":\(arrowHead.shape.serialize()),\"color\":\"\(escapeJSON(arrowHead.color))\"}"
        }

        if let arrowTail = arrowTail {
            result += ",\"arrowTail\":{\"shape\":\(arrowTail.shape.serialize()),\"color\":\"\(escapeJSON(arrowTail.color))\"}"
        }

        if let color = color {
            result += ",\"color\":\"\(escapeJSON(color))\""
        }

        if let style = style {
            result += ",\"style\":\"\(escapeJSON(style))\""
        }

        if let penwidth = penwidth {
            result += ",\"penwidth\":\(penwidth)"
        }

        if let label = label {
            result +=
                ",\"label\":{\"text\":\"\(escapeJSON(label.text))\",\"position\":{\"x\":\(label.position.x),\"y\":\(label.position.y)}"
            if let fontSize = label.fontSize {
                result += ",\"fontSize\":\(fontSize)"
            }
            if let fontFamily = label.fontFamily {
                result += ",\"fontFamily\":\"\(escapeJSON(fontFamily))\""
            }
            result += "}"
        }

        if let headLabel = headLabel {
            result +=
                ",\"headLabel\":{\"text\":\"\(escapeJSON(headLabel.text))\",\"position\":{\"x\":\(headLabel.position.x),\"y\":\(headLabel.position.y)}"
            if let fontSize = headLabel.fontSize {
                result += ",\"fontSize\":\(fontSize)"
            }
            if let fontFamily = headLabel.fontFamily {
                result += ",\"fontFamily\":\"\(escapeJSON(fontFamily))\""
            }
            result += "}"
        }

        if let tailLabel = tailLabel {
            result +=
                ",\"tailLabel\":{\"text\":\"\(escapeJSON(tailLabel.text))\",\"position\":{\"x\":\(tailLabel.position.x),\"y\":\(tailLabel.position.y)}"
            if let fontSize = tailLabel.fontSize {
                result += ",\"fontSize\":\(fontSize)"
            }
            if let fontFamily = tailLabel.fontFamily {
                result += ",\"fontFamily\":\"\(escapeJSON(fontFamily))\""
            }
            result += "}"
        }

        result += "}"
        return result
    }

    public static func fromString(_ string: String) throws(VError) -> EdgeLayoutData {
        // Manual JSON-like parsing to avoid JSONDecoder (not available in WASM)

        func extractString(after pattern: String, in text: String) -> String? {
            guard let start = text.range(of: pattern) else { return nil }
            var value = ""
            var index = start.upperBound
            var escaped = false

            while index < text.endIndex {
                let char = text[index]
                if escaped {
                    value.append(char)
                    escaped = false
                } else if char == "\\" {
                    escaped = true
                } else if char == "\"" {
                    break
                } else {
                    value.append(char)
                }
                index = text.index(after: index)
            }
            return value.isEmpty ? nil : value
        }

        func extractDouble(after pattern: String, in text: String) -> Double? {
            guard let start = text.range(of: pattern) else { return nil }
            var numStr = ""
            var index = start.upperBound

            while index < text.endIndex {
                let char = text[index]
                guard char.isNumber || char == "." || char == "-" else {
                    break
                }
                numStr.append(char)
                index = text.index(after: index)
            }
            return Double(numStr)
        }

        var splinePoints: [VPoint] = []
        if let spStart = string.range(of: "\"splinePoints\":[") {
            var index = spStart.upperBound
            var bracketCount = 1

            while index < string.endIndex && bracketCount > 0 {
                let char = string[index]
                if char == "[" {
                    bracketCount += 1
                } else if char == "]" {
                    bracketCount -= 1
                    if bracketCount == 0 {
                        break
                    }
                }
                index = string.index(after: index)
            }

            let spArray = String(string[spStart.upperBound..<index])
            // Parse points: [{\"x\":48.35,\"y\":232.06},{\"x\":30.37,\"y\":240.76},...]
            let pointStrings = spArray.components(separatedBy: "},{")
            for pointStr in pointStrings {
                let cleaned = pointStr.replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: "")
                if let x = extractDouble(after: "\"x\":", in: cleaned),
                    let y = extractDouble(after: "\"y\":", in: cleaned)
                {
                    splinePoints.append(VPoint(x: x, y: y))
                }
            }
        }

        guard !splinePoints.isEmpty else {
            throw VError.parsingError("EdgeLayoutData: missing or empty splinePoints field")
        }

        // Helper to extract arrow data (used for both arrowHead and arrowTail)
        func extractArrow(key: String, from string: String) -> ArrowHeadData? {
            guard string.contains("\"\(key)\"") else { return nil }

            if let ahStart = string.range(of: "\"\(key)\":{") {
                var ahEnd: String.Index? = nil
                var braceCount = 1
                var index = ahStart.upperBound

                while index < string.endIndex && braceCount > 0 {
                    let char = string[index]
                    if char == "{" {
                        braceCount += 1
                    } else if char == "}" {
                        braceCount -= 1
                        if braceCount == 0 {
                            ahEnd = index
                            break
                        }
                    }
                    index = string.index(after: index)
                }

                guard let endIndex = ahEnd else { return nil }
                let ahSection = String(string[ahStart.upperBound..<endIndex])

                guard let ahColor = extractString(after: "\"color\":\"", in: ahSection) else { return nil }

                if ahSection.contains("\"shape\":{") {
                    if let shapeStart = ahSection.range(of: "\"shape\":{") {
                        var shapeEnd: String.Index? = nil
                        var shapeBraceCount = 1
                        var shapeIndex = shapeStart.upperBound

                        while shapeIndex < ahSection.endIndex && shapeBraceCount > 0 {
                            let char = ahSection[shapeIndex]
                            if char == "{" {
                                shapeBraceCount += 1
                            } else if char == "}" {
                                shapeBraceCount -= 1
                                if shapeBraceCount == 0 {
                                    shapeEnd = shapeIndex
                                    break
                                }
                            }
                            shapeIndex = ahSection.index(after: shapeIndex)
                        }

                        if let shapeEndIndex = shapeEnd {
                            let shapeJSON = "{" + String(ahSection[shapeStart.upperBound..<shapeEndIndex]) + "}"
                            if let shape = try? Shape.deserialize(shapeJSON) {
                                return ArrowHeadData(shape: shape, color: ahColor)
                            }
                        }
                    }
                }
            }
            return nil
        }

        let arrowHead = extractArrow(key: "arrowHead", from: string)

        let arrowTail = extractArrow(key: "arrowTail", from: string)

        // Extract edge color (outside arrowHead and arrowTail)
        // We need to find "color" that's NOT inside the arrow objects
        var edgeColor: String? = nil
        if arrowHead != nil || arrowTail != nil {
            var searchStart = string.startIndex

            for arrowKey in ["arrowHead", "arrowTail"] {
                if let arrowEnd = string.range(of: "\"\(arrowKey)\":{")?.upperBound {
                    var braceCount = 1
                    var index = arrowEnd
                    while index < string.endIndex && braceCount > 0 {
                        let char = string[index]
                        if char == "{" {
                            braceCount += 1
                        } else if char == "}" {
                            braceCount -= 1
                        }
                        index = string.index(after: index)
                    }
                    if index > searchStart {
                        searchStart = index
                    }
                }
            }

            let remainingString = String(string[searchStart...])
            edgeColor = extractString(after: "\"color\":\"", in: remainingString)
        } else {
            // No arrows, so any color field is the edge color
            edgeColor = extractString(after: "\"color\":\"", in: string)
        }

        let style = extractString(after: "\"style\":\"", in: string)

        let penwidth = extractDouble(after: "\"penwidth\":", in: string)

        var label: LabelData? = nil
        if string.contains("\"label\"") {
            let lSection =
                string.components(separatedBy: "\"label\":{").last?.components(separatedBy: "}").first ?? ""
            if let text = extractString(after: "\"text\":\"", in: lSection),
                let x = extractDouble(after: "\"x\":", in: lSection),
                let y = extractDouble(after: "\"y\":", in: lSection)
            {
                let fontSize = extractDouble(after: "\"fontSize\":", in: lSection)
                let fontFamily = extractString(after: "\"fontFamily\":\"", in: lSection)
                label = LabelData(
                    text: text, position: VPoint(x: x, y: y), fontSize: fontSize, fontFamily: fontFamily)
            }
        }

        var headLabel: LabelData? = nil
        if string.contains("\"headLabel\"") {
            let hlSection =
                string.components(separatedBy: "\"headLabel\":{").last?.components(separatedBy: "}").first ?? ""
            if let text = extractString(after: "\"text\":\"", in: hlSection),
                let x = extractDouble(after: "\"x\":", in: hlSection),
                let y = extractDouble(after: "\"y\":", in: hlSection)
            {
                let fontSize = extractDouble(after: "\"fontSize\":", in: hlSection)
                let fontFamily = extractString(after: "\"fontFamily\":\"", in: hlSection)
                headLabel = LabelData(
                    text: text, position: VPoint(x: x, y: y), fontSize: fontSize, fontFamily: fontFamily)
            }
        }

        var tailLabel: LabelData? = nil
        if string.contains("\"tailLabel\"") {
            let tlSection =
                string.components(separatedBy: "\"tailLabel\":{").last?.components(separatedBy: "}").first ?? ""
            if let text = extractString(after: "\"text\":\"", in: tlSection),
                let x = extractDouble(after: "\"x\":", in: tlSection),
                let y = extractDouble(after: "\"y\":", in: tlSection)
            {
                let fontSize = extractDouble(after: "\"fontSize\":", in: tlSection)
                let fontFamily = extractString(after: "\"fontFamily\":\"", in: tlSection)
                tailLabel = LabelData(
                    text: text, position: VPoint(x: x, y: y), fontSize: fontSize, fontFamily: fontFamily)
            }
        }

        return EdgeLayoutData(
            splinePoints: splinePoints,
            arrowHead: arrowHead,
            arrowTail: arrowTail,
            color: edgeColor,
            style: style,
            penwidth: penwidth,
            label: label,
            headLabel: headLabel,
            tailLabel: tailLabel
        )
    }

    private func escapeJSON(_ string: String) -> String {
        return
            string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
}
