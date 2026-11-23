/// An arrowhead as the layout engine drew it: a circle stays a circle rather
/// than becoming a polygon approximation.
public enum Shape: VProtocol, Equatable {
    case circle(center: VPoint, radius: Double)

    case ellipse(center: VPoint, radiusX: Double, radiusY: Double)

    case polygon(points: [VPoint])

    case spline(controlPoints: [VPoint])

    // MARK: - String form

    public var asString: String {
        switch self {
        case .circle(let center, let radius):
            return "{\"type\":\"circle\",\"center\":\(LayoutDataText.point(center)),\"radius\":\(radius)}"

        case .ellipse(let center, let radiusX, let radiusY):
            return
                "{\"type\":\"ellipse\",\"center\":\(LayoutDataText.point(center)),\"radiusX\":\(radiusX),\"radiusY\":\(radiusY)}"

        case .polygon(let points):
            return "{\"type\":\"polygon\",\"points\":[\(points.map { LayoutDataText.point($0) }.joined(separator: ","))]}"

        case .spline(let controlPoints):
            return
                "{\"type\":\"spline\",\"controlPoints\":[\(controlPoints.map { LayoutDataText.point($0) }.joined(separator: ","))]}"
        }
    }

    public static func fromString(_ string: String) throws(VError) -> Shape {
        guard let typeValue = LayoutDataText.string("type", in: string) else {
            throw VError.parsingError("Shape: missing type field")
        }

        switch typeValue {
        case "circle":
            guard let center = LayoutDataText.points(in: string).first,
                let radius = LayoutDataText.double("radius", in: string)
            else {
                throw VError.parsingError("Shape: invalid circle format")
            }
            return .circle(center: center, radius: radius)

        case "ellipse":
            guard let center = LayoutDataText.points(in: string).first,
                let radiusX = LayoutDataText.double("radiusX", in: string),
                let radiusY = LayoutDataText.double("radiusY", in: string)
            else {
                throw VError.parsingError("Shape: invalid ellipse format")
            }
            return .ellipse(center: center, radiusX: radiusX, radiusY: radiusY)

        case "polygon":
            let points = LayoutDataText.points(in: string)
            guard !points.isEmpty else {
                throw VError.parsingError("Shape: polygon has no points")
            }
            return .polygon(points: points)

        case "spline":
            let controlPoints = LayoutDataText.points(in: string)
            guard !controlPoints.isEmpty else {
                throw VError.parsingError("Shape: spline has no control points")
            }
            return .spline(controlPoints: controlPoints)

        default:
            throw VError.parsingError("Shape: unknown type '\(typeValue)'")
        }
    }
}
