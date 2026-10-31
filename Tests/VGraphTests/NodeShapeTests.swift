import Testing

@testable import VGraph

@Suite
struct NodeShapeTests {

    @Test("Given the cylinder shape, when serialized and parsed back, then it round-trips")
    func cylinderRoundTrips() throws(VError) {
        #expect(try NodeShape.fromString(NodeShape.cylinder.asString) == .cylinder)
    }

    @Test("Given the person shape, when serialized and parsed back, then it round-trips")
    func personRoundTrips() throws(VError) {
        #expect(try NodeShape.fromString(NodeShape.person.asString) == .person)
    }
}
