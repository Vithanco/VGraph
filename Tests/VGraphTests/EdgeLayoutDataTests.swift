import Foundation
import Testing
import VGraph

@Suite("EdgeLayoutData Serialization Tests")
struct EdgeLayoutDataTests {

    /// Test that EdgeLayoutData with arrow head data can be serialized and deserialized correctly
    /// Uses real data from Graphviz JSON output
    @Test func testEdgeLayoutDataWithArrowHeadRoundtrip() throws {
        // Real arrow head data from Graphviz JSON:
        // "_hdraw_":[{"op":"S","style":"solid"},{"op":"c","grad":"none","color":"#000000"},
        //            {"op":"C","grad":"none","color":"#000000"},
        //            {"op":"P","points":[[269.16,217.82],[265.66,207.82],[262.16,217.83]]}]

        // Create arrow head data with flipped Y coordinates (graph height = 281.6)
        let polygonPoints = [
            VPoint(x: 269.16, y: 63.78),
            VPoint(x: 265.66, y: 73.78),
            VPoint(x: 262.16, y: 63.77),
        ]
        let arrowHead = ArrowHeadData(shape: .polygon(points: polygonPoints), color: "#000000")

        // Create edge layout data with spline points, arrow head, and styling
        // Spline points representing: M 265.66 39.61 C 265.66 46.89, 265.66 55.51, 265.66 63.98
        // Format: 4 points (3*1+1) for one cubic Bezier curve
        let splinePoints = [
            VPoint(x: 265.66, y: 39.61),  // Start point
            VPoint(x: 265.66, y: 46.89),  // Control point 1
            VPoint(x: 265.66, y: 55.51),  // Control point 2
            VPoint(x: 265.66, y: 63.98),  // End point
        ]
        let original = EdgeLayoutData(
            splinePoints: splinePoints,
            arrowHead: arrowHead,
            color: "#ff0000",
            style: "dashed",
            penwidth: 3.0
        )

        let serialized = original.asString

        #expect(serialized.contains("\"splinePoints\":"))
        #expect(serialized.contains("\"arrowHead\":"))
        #expect(serialized.contains("\"shape\":"))
        #expect(serialized.contains("\"color\":\"#ff0000\""))  // Edge color
        #expect(serialized.contains("\"style\":\"dashed\""))
        #expect(serialized.contains("\"penwidth\":3"))

        let deserialized = try EdgeLayoutData.fromString(serialized)

        #expect(deserialized.splinePoints.count == splinePoints.count)
        for (i, point) in deserialized.splinePoints.enumerated() {
            #expect(abs(point.x - splinePoints[i].x) < 0.01)
            #expect(abs(point.y - splinePoints[i].y) < 0.01)
        }

        #expect(deserialized.arrowHead != nil)

        guard let deserializedArrowHead = deserialized.arrowHead else {
            Issue.record("Arrow head was lost during deserialization")
            return
        }

        #expect(deserializedArrowHead.color == "#000000")

        #expect(deserializedArrowHead.polygonPoints.count == 3)

        #expect(deserialized.color == "#ff0000")
        #expect(deserialized.style == "dashed")
        #expect(deserialized.penwidth == 3.0)

        // Verify polygon points are approximately equal (allowing for floating point precision)
        for (i, point) in deserializedArrowHead.polygonPoints.enumerated() {
            let originalPoint = polygonPoints[i]
            #expect(abs(point.x - originalPoint.x) < 0.01)
            #expect(abs(point.y - originalPoint.y) < 0.01)
        }
    }

    @Test func testEdgeLayoutDataWithoutArrowHead() throws {
        // Simple straight line: M 100 100 L 200 200
        // As 4-point spline (3*1+1): start, cp1, cp2, end
        let splinePoints = [
            VPoint(x: 100, y: 100),
            VPoint(x: 133.33, y: 133.33),
            VPoint(x: 166.67, y: 166.67),
            VPoint(x: 200, y: 200),
        ]
        let original = EdgeLayoutData(splinePoints: splinePoints, arrowHead: nil)

        let serialized = original.asString

        // Should contain splinePoints but not arrowHead
        #expect(serialized.contains("\"splinePoints\":"))
        #expect(!serialized.contains("\"arrowHead\":"))

        let deserialized = try EdgeLayoutData.fromString(serialized)

        #expect(deserialized.splinePoints.count == splinePoints.count)
        for (i, point) in deserialized.splinePoints.enumerated() {
            #expect(abs(point.x - splinePoints[i].x) < 0.01)
            #expect(abs(point.y - splinePoints[i].y) < 0.01)
        }
        #expect(deserialized.arrowHead == nil)
    }

    @Test func testSplinePointsSerialization() throws {
        // Simple spline with 4 points (3*1+1)
        let splinePoints = [
            VPoint(x: 100, y: 100),
            VPoint(x: 150.5, y: 150.5),
            VPoint(x: 200.75, y: 200.75),
            VPoint(x: 250, y: 250),
        ]
        let original = EdgeLayoutData(splinePoints: splinePoints, arrowHead: nil)

        let serialized = original.asString

        let deserialized = try EdgeLayoutData.fromString(serialized)

        // The spline points should be properly serialized and deserialized
        #expect(deserialized.splinePoints.count == splinePoints.count)
        for (i, point) in deserialized.splinePoints.enumerated() {
            #expect(abs(point.x - splinePoints[i].x) < 0.01)
            #expect(abs(point.y - splinePoints[i].y) < 0.01)
        }
    }
}
