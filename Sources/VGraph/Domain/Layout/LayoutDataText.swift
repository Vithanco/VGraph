/// The JSON-like text layout values are stored as. Hand-written because Embedded
/// Swift has no `JSONEncoder`; only what `EdgeLayoutData` and `Shape` write is read.
enum LayoutDataText {

    static func point(_ point: VPoint) -> String {
        "{\"x\":\(point.x),\"y\":\(point.y)}"
    }

    static func quoted(_ text: String) -> String {
        var result = "\""
        for char in text {
            switch char {
            case "\\": result += "\\\\"
            case "\"": result += "\\\""
            case "\n": result += "\\n"
            default: result.append(char)
            }
        }
        return result + "\""
    }

    /// The string value that follows `"key":`, or nil when there is none or it is empty.
    static func string(_ key: String, in text: String) -> String? {
        guard let start = text.range(of: "\"\(key)\":\"") else { return nil }
        var value = ""
        var escaped = false
        for char in text[start.upperBound...] {
            if escaped {
                value.append(char == "n" ? "\n" : char)
                escaped = false
            } else if char == "\\" {
                escaped = true
            } else if char == "\"" {
                break
            } else {
                value.append(char)
            }
        }
        return value.isEmpty ? nil : value
    }

    static func double(_ key: String, in text: String) -> Double? {
        guard let start = text.range(of: "\"\(key)\":") else { return nil }
        let digits = text[start.upperBound...].prefix { $0.isNumber || ".-+eE".contains($0) }
        return Double(String(digits))
    }

    /// Every `{"x":…,"y":…}` in `text`, in order.
    static func points(in text: String) -> [VPoint] {
        text.components(separatedBy: "{\"x\":").dropFirst().compactMap { entry in
            let parts = entry.components(separatedBy: ",\"y\":")
            guard parts.count >= 2,
                let x = Double(parts[0].trimmingWhitespace()),
                let y = Double(parts[1].components(separatedBy: "}")[0].trimmingWhitespace())
            else { return nil }
            return VPoint(x: x, y: y)
        }
    }

    /// The text between the braces of the object `"key":{…}`, braces inside
    /// strings not counting.
    static func object(_ key: String, in text: String) -> Substring? {
        objectRange(key, in: text).map { text[$0] }
    }

    static func objectRange(_ key: String, in text: String) -> Range<String.Index>? {
        guard let start = text.range(of: "\"\(key)\":{") else { return nil }
        var depth = 1
        var inString = false
        var escaped = false
        var index = start.upperBound
        while index < text.endIndex {
            let char = text[index]
            if escaped {
                escaped = false
            } else if char == "\\" {
                escaped = inString
            } else if char == "\"" {
                inString.toggle()
            } else if !inString && char == "{" {
                depth += 1
            } else if !inString && char == "}" {
                depth -= 1
                if depth == 0 { return start.upperBound..<index }
            }
            index = text.index(after: index)
        }
        return nil
    }
}
