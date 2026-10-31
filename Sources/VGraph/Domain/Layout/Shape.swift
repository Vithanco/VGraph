/// Represents geometric shapes used in graph rendering
/// This allows preserving original shape information (e.g., circles)
/// rather than converting everything to polygon approximations
public enum Shape: VProtocol, Equatable {
    case circle(center: VPoint, radius: Double)

    case ellipse(center: VPoint, radiusX: Double, radiusY: Double)

    case polygon(points: [VPoint])

    case spline(controlPoints: [VPoint])

    /// Convert shape to polygon points for backward compatibility
    public func toPolygonPoints() -> [VPoint] {
        switch self {
        case .circle(let center, let radius):
            return approximateCircle(center: center, radiusX: radius, radiusY: radius, numPoints: 16)

        case .ellipse(let center, let radiusX, let radiusY):
            return approximateCircle(center: center, radiusX: radiusX, radiusY: radiusY, numPoints: 16)

        case .polygon(let points):
            return points

        case .spline(let controlPoints):
            // For splines, we approximate with the control points
            return controlPoints
        }
    }

    private func approximateCircle(center: VPoint, radiusX: Double, radiusY: Double, numPoints: Int) -> [VPoint] {
        var points: [VPoint] = []
        for i in 0..<numPoints {
            let angle = Double(i) * 2.0 * 3.14159265359 / Double(numPoints)
            let cosAngle = approximateCos(angle)
            let sinAngle = approximateSin(angle)
            let x = center.x + radiusX * cosAngle
            let y = center.y + radiusY * sinAngle
            points.append(VPoint(x: x, y: y))
        }
        return points
    }

    private func approximateCos(_ x: Double) -> Double {
        var angle = x
        while angle > 3.14159265359 {
            angle -= 2.0 * 3.14159265359
        }
        while angle < -3.14159265359 {
            angle += 2.0 * 3.14159265359
        }

        // Taylor series: cos(x) ≈ 1 - x²/2! + x⁴/4! - x⁶/6! + x⁸/8!
        let x2 = angle * angle
        let x4 = x2 * x2
        let x6 = x4 * x2
        let x8 = x6 * x2

        return 1.0 - x2 / 2.0 + x4 / 24.0 - x6 / 720.0 + x8 / 40320.0
    }

    private func approximateSin(_ x: Double) -> Double {
        var angle = x
        while angle > 3.14159265359 {
            angle -= 2.0 * 3.14159265359
        }
        while angle < -3.14159265359 {
            angle += 2.0 * 3.14159265359
        }

        // Taylor series: sin(x) ≈ x - x³/3! + x⁵/5! - x⁷/7! + x⁹/9!
        let x2 = angle * angle
        let x3 = x2 * angle
        let x5 = x3 * x2
        let x7 = x5 * x2
        let x9 = x7 * x2

        return angle - x3 / 6.0 + x5 / 120.0 - x7 / 5040.0 + x9 / 362880.0
    }

    // MARK: - Serialization Support

    public func serialize() -> String {
        switch self {
        case .circle(let center, let radius):
            return "{\"type\":\"circle\",\"center\":{\"x\":\(center.x),\"y\":\(center.y)},\"radius\":\(radius)}"

        case .ellipse(let center, let radiusX, let radiusY):
            return "{\"type\":\"ellipse\",\"center\":{\"x\":\(center.x),\"y\":\(center.y)},\"radiusX\":\(radiusX),\"radiusY\":\(radiusY)}"

        case .polygon(let points):
            let pointsJSON = points.map { "{\"x\":\($0.x),\"y\":\($0.y)}" }.joined(separator: ",")
            return "{\"type\":\"polygon\",\"points\":[\(pointsJSON)]}"

        case .spline(let controlPoints):
            let pointsJSON = controlPoints.map { "{\"x\":\($0.x),\"y\":\($0.y)}" }.joined(separator: ",")
            return "{\"type\":\"spline\",\"controlPoints\":[\(pointsJSON)]}"
        }
    }

    public static func deserialize(_ string: String) throws(VError) -> Shape {
        guard let typeValue = extractString(after: "\"type\":\"", in: string) else {
            throw VError.parsingError("Shape: missing type field")
        }

        switch typeValue {
        case "circle":
            guard let centerX = extractDouble(after: "\"center\":{\"x\":", in: string),
                let centerY = extractDouble(after: "\"y\":", in: string),
                let radius = extractDouble(after: "\"radius\":", in: string)
            else {
                throw VError.parsingError("Shape: invalid circle format")
            }
            return .circle(center: VPoint(x: centerX, y: centerY), radius: radius)

        case "ellipse":
            guard let centerX = extractDouble(after: "\"center\":{\"x\":", in: string),
                let centerY = extractDouble(after: "\"y\":", in: string),
                let radiusX = extractDouble(after: "\"radiusX\":", in: string),
                let radiusY = extractDouble(after: "\"radiusY\":", in: string)
            else {
                throw VError.parsingError("Shape: invalid ellipse format")
            }
            return .ellipse(center: VPoint(x: centerX, y: centerY), radiusX: radiusX, radiusY: radiusY)

        case "polygon":
            var points: [VPoint] = []
            let pointStrings = string.components(separatedBy: "{\"x\":")
            for pointStr in pointStrings.dropFirst() {
                let parts = pointStr.components(separatedBy: ",\"y\":")
                guard parts.count >= 2 else { continue }

                let xStr = parts[0].trimmingWhitespace()
                let yPart = parts[1].components(separatedBy: "}")[0]
                let yStr = yPart.trimmingWhitespace()

                if let x = Double(xStr), let y = Double(yStr) {
                    points.append(VPoint(x: x, y: y))
                }
            }
            guard !points.isEmpty else {
                throw VError.parsingError("Shape: polygon has no points")
            }
            return .polygon(points: points)

        case "spline":
            var controlPoints: [VPoint] = []
            let pointStrings = string.components(separatedBy: "{\"x\":")
            for pointStr in pointStrings.dropFirst() {
                let parts = pointStr.components(separatedBy: ",\"y\":")
                guard parts.count >= 2 else { continue }

                let xStr = parts[0].trimmingWhitespace()
                let yPart = parts[1].components(separatedBy: "}")[0]
                let yStr = yPart.trimmingWhitespace()

                if let x = Double(xStr), let y = Double(yStr) {
                    controlPoints.append(VPoint(x: x, y: y))
                }
            }
            guard !controlPoints.isEmpty else {
                throw VError.parsingError("Shape: spline has no control points")
            }
            return .spline(controlPoints: controlPoints)

        default:
            throw VError.parsingError("Shape: unknown type '\(typeValue)'")
        }
    }

    // MARK: - Helper functions for parsing

    private static func extractString(after pattern: String, in text: String) -> String? {
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

    private static func extractDouble(after pattern: String, in text: String) -> Double? {
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
}
