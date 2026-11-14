import Testing

@testable import VGraph

@Suite
struct NodeShapeTests {

    @Test(
        "Given a node shape, when serialized and parsed back, then it round-trips",
        arguments: [NodeShape.box, .circle, .point, .cylinder, .person])
    func shapeRoundTrips(_ shape: NodeShape) throws(VError) {
        #expect(try NodeShape.fromString(shape.asString) == shape)
    }
}
