import TestSupport
import Testing

@testable import VGraph

@Suite
struct C4ShapeTests {

    private func cardStyleString(_ nodeType: NodeType) throws(VError) -> String {
        let graph = try Notations.C4.addNotation(addTo: VGraph().defineStandardAttributes())
        return try graph.get(nodeType: nodeType, attribute: Attributes.Node.style).asString
    }

    @Test("Given the C4 notation, when a Person element's card is inspected, then its background shape is the person shape")
    func personUsesPersonShape() throws(VError) {
        #expect(try cardStyleString(Notations.C4.NodeTypes.person).contains("person"))
    }

    @Test("Given the C4 notation, when a Database element's card is inspected, then its background shape is the cylinder shape")
    func databaseUsesCylinderShape() throws(VError) {
        #expect(try cardStyleString(Notations.C4.NodeTypes.database).contains("cylinder"))
    }

    @Test("Given the C4 notation, when a Software System element's card is inspected, then its background shape stays a box")
    func softwareSystemStaysBox() throws(VError) {
        let style = try cardStyleString(Notations.C4.NodeTypes.softwareSystem)
        #expect(style.contains("box"))
        #expect(!style.contains("cylinder"))
        #expect(!style.contains("person"))
    }
}
