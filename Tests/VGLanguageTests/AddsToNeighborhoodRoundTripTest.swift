// A `vnotation` reads and writes each node type key by name, so a key that
// parses but does not export (or the reverse) is the failure caught here.

import Testing

@testable import VGLanguage
@testable import VGraph

@Suite("addsToNeighborhood through vnotation")
struct AddsToNeighborhoodRoundTripTest {

    private func parse(_ source: String) throws -> VGraph {
        try VGraphParser(logger: NoOpLogger()).parse(source: source)
    }

    private func source(adds: String) -> String {
        """
        vnotation Facts {
            node type: Thing [nodeStyle: bareText]
            node type: Verb [nodeStyle: bareText, addsToNeighborhood: \(adds)]
            edge type: subject from: Thing to: Verb
            edge type: object from: Verb to: Thing
        }
        vgraph f: Facts "F" {
            node a: Thing "A";
            node v: Verb "v";
            node b: Thing "B";
            edge a -> v;
            edge v -> b;
        }
        """
    }

    @Test func aDeclaredValueSurvivesExport() throws {
        let exported = try VGLExporter().export(graph: parse(source(adds: "onward")))
        let reparsed = try parse(exported)

        #expect(try reparsed.get(nodeType: NodeType(string: "Verb"), attribute: Attributes.Node.addsToNeighborhood) == .onward)
        #expect(try reparsed.get(nodeType: NodeType(string: "Thing"), attribute: Attributes.Node.addsToNeighborhood) == .none)
    }

    @Test func aValueThatIsNotOneOfTheThreeIsRefused() {
        #expect(throws: VError.conversionError(from: "sideways", to: AddsToNeighborhood.typeName)) {
            try parse(source(adds: "sideways"))
        }
    }
}
