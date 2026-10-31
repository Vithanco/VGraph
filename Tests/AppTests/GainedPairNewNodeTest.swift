import Testing
import VGLanguage
import VGraph

@testable import App

/// Commands that create a node on a relationship read gained pairs too
/// (ADR-0032).
struct GainedPairNewNodeTest {
    private func session() throws -> TestSession {
        try makeTestSession(
            vgl: """
                vnotation Arch {
                  node type: Person [nodeStyle: roundedBox]
                  node type: System [nodeStyle: roundedBox, detailedBy: (Container)]
                  node type: Container [nodeStyle: roundedBox]
                  edge type: uses from: Person to: System
                  edge type: delivers from: System to: Person
                }

                vgraph g: Arch "G" {
                  group shop: System "Shop" {
                    node spa: Container "SPA";
                  };
                }
                """)
    }

    private func added(in s: TestSession) throws -> Node {
        try #require(s.origin.nodes.first { $0.id != "spa" })
    }

    @Test("Given a Container in a System, when adding a successor, then the System's relationship is offered")
    func aSuccessorOfADetailUsesTheGainedPair() throws {
        let s = try session()

        #expect(s.successorCandidates(from: "spa").map { $0.edgeType.id.id } == ["delivers"])

        try s.addSuccessor(from: "spa", using: EdgeType.Id(string: "delivers"))
        #expect(try s.origin.nodeType(for: try added(in: s)).id == "Person")
        #expect(try s.origin.edgeType(for: s.origin.edges[0]).id.id == "delivers")
    }

    @Test("Given a Container in a System, when adding a predecessor, then the System's relationship is offered")
    func aPredecessorOfADetailUsesTheGainedPair() throws {
        let s = try session()

        #expect(s.predecessorCandidates(to: "spa").map { $0.edgeType.id.id } == ["uses"])

        try s.addPredecessor(to: "spa", using: EdgeType.Id(string: "uses"))
        #expect(try s.origin.nodeType(for: try added(in: s)).id == "Person")
        #expect(try s.origin.edgeType(for: s.origin.edges[0]).id.id == "uses")
    }

    /// A Person inside the System would be a misplaced detail; it goes where the
    /// System stands, which is where the relationship is declared.
    @Test("Given a Container in a System, when adding a Person to it, then the Person stands beside the System")
    func theNewNodeStandsWhereTheRelationshipIsDeclared() throws {
        let s = try session()

        try s.addSuccessor(from: "spa", using: EdgeType.Id(string: "delivers"))

        let person = try added(in: s)
        #expect(s.origin.detailedNode(holding: s.origin.group(of: person)) == nil)
    }

    @Test("Given an edge from a Person to a Container, when splitting it, then a System between them is offered")
    func splittingAGainedPairOffersTheDeclaredLevel() throws {
        let s = try makeTestSession(
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
                  group shop: System "Shop" {
                    node spa: Container "SPA";
                  };
                  edge customer -> spa;
                }
                """)
        let edge = s.origin.edges[0].id.id

        let candidates = s.splitCandidates(for: edge)
        #expect(candidates.map { $0.title } == ["System"])

        try s.split(edge, with: try #require(candidates.first))
        let exported = try s.exportVGL()
        #expect(exported.contains("node system_1: System"), "\(exported)")
        #expect(exported.contains("edge customer -> system_1"), "\(exported)")
        #expect(exported.contains("edge system_1 -> spa"), "\(exported)")
        #expect(GenericQualityChecks.unknownEdgeTypes(graph: s.origin).isEmpty)
    }
}
