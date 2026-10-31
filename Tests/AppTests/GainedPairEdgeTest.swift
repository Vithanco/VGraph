import Testing
import VGLanguage
import VGraph

@testable import App

/// An edge to a detail takes its declared relationship (ADR-0032).
struct GainedPairEdgeTest {
    private func session(edges: String) throws -> TestSession {
        try makeTestSession(
            vgl: """
                vnotation Arch {
                  node type: Person [nodeStyle: roundedBox]
                  node type: System [nodeStyle: roundedBox, detailedBy: (Container)]
                  node type: Container [nodeStyle: roundedBox]
                  edge type: uses from: Person to: System
                  edge type: talks from: System to: System
                }

                vgraph g: Arch "G" {
                  node customer: Person "Customer";
                  node spa: Container "SPA";
                  node api: Container "API";
                \(edges)
                }
                """)
    }

    private func typeOfOnlyEdge(_ s: TestSession) throws -> String {
        try #require(s.origin.edges.count == 1)
        return try s.origin.edgeType(for: s.origin.edges[0]).id.id
    }

    @Test("Given an untyped edge on a gained pair, when parsed, then it takes the declared type")
    func anUntypedEdgeInfersItsDeclaredType() throws {
        let s = try session(edges: "  edge customer -> spa;")
        #expect(try typeOfOnlyEdge(s) == "uses")
        #expect(GenericQualityChecks.unknownEdgeTypes(graph: s.origin).isEmpty)
    }

    @Test("Given a typed edge on a gained pair, when parsed, then it keeps the type")
    func aTypedEdgeOnAGainedPairIsValid() throws {
        let s = try session(edges: "  edge customer -> spa: uses;")
        #expect(try typeOfOnlyEdge(s) == "uses")
        #expect(GenericQualityChecks.unknownEdgeTypes(graph: s.origin).isEmpty)
    }

    @Test("Given an edge between details at both ends, when parsed, then no type is gained for it")
    func bothEndsDetailsGainNothing() throws {
        let s = try session(edges: "  edge spa -> api;")
        #expect(try typeOfOnlyEdge(s).hasPrefix(EdgeType.unknownPrefix))
    }

    @Test("Given an edge on an unambiguous gained pair, when exported, then its type is omitted")
    func exportOmitsAnInferrableType() throws {
        let s = try session(edges: "  edge customer -> spa: uses;")
        let exported = try s.exportVGL()
        #expect(exported.contains("edge customer -> spa\n") || exported.contains("edge customer -> spa \""), "\(exported)")
        #expect(!exported.contains("customer -> spa: uses"), "\(exported)")
    }
}
