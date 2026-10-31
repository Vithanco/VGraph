import TestSupport
import Testing

@testable import VGraph

@Suite
struct C4StyleTests {

    private func c4Graph() throws(VError) -> VGraph {
        return try Notations.C4.addNotation(addTo: VGraph().defineStandardAttributes())
    }

    // MARK: - Element cards

    @Test("Given the C4 notation, when a Software System element's style is inspected, then the card shows its «Software System» stereotype")
    func softwareSystemCardShowsStereotype() throws(VError) {
        let graph = try c4Graph()
        let style = try graph.get(nodeType: Notations.C4.NodeTypes.softwareSystem, attribute: Attributes.Node.style)
        #expect(style.asString.contains("Software System"))
    }
}
