import Testing

@testable import VGLanguage
@testable import VGraph

/// A file names an edge's type only when the pair is ambiguous, gained pairs included (ADR-0032).
@Suite("Gained pairs in VGL")
struct GainedPairVGLTest {
    static let source = """
        vnotation Arch {
        	node type: Person [nodeStyle: roundedBox]
        	node type: System [nodeStyle: roundedBox, detailedBy: (Container)]
        	node type: Container [nodeStyle: roundedBox]
        	edge type: uses from: Person to: System
        	edge type: reads from: Person to: Container
        	edge type: delivers from: System to: Person
        	edge type: notifies from: System to: Person
        }

        vgraph g: Arch "G" {
        	node customer: Person "Customer"
        	node spa: Container "SPA"
        	edge customer -> spa
        	edge spa -> customer: notifies
        }
        """

    private func parse(_ source: String) throws -> VGraph {
        try VGraphParser(logger: NoOpLogger()).parse(source: source)
    }

    private func types(_ graph: VGraph) throws -> [String] {
        try graph.edges.map { edge in try graph.edgeType(for: edge.id).id.id }
    }

    @Test("Given a pair a type declares, when parsed, then a type that would gain it does not")
    func aDeclaredPairWinsOverAGainedOne() throws {
        #expect(try types(parse(Self.source)) == ["reads", "notifies"])
    }

    @Test("Given an edge on an ambiguous gained pair, when exported and reparsed, then its type is written and kept")
    func anAmbiguousGainedPairNamesItsType() throws {
        let exported = try VGLExporter().export(graph: parse(Self.source))
        #expect(exported.contains("edge spa -> customer: notifies"), "\(exported)")
        #expect(!exported.contains("edge customer -> spa:"), "\(exported)")
        #expect(try types(parse(exported)) == ["reads", "notifies"])
    }
}
