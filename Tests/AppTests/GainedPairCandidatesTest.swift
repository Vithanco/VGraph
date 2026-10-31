import EditorCore
import Testing
import VGLanguage
import VGraph

@testable import App

/// The editor offers what the graph accepts on gained pairs (ADR-0032).
struct GainedPairCandidatesTest {
    private func session(edgeTypes: String = "", nodes: String = "", edges: String = "") throws -> TestSession {
        try makeTestSession(
            vgl: """
                vnotation Arch {
                  node type: Person [nodeStyle: roundedBox]
                  node type: System [nodeStyle: roundedBox, detailedBy: (Container)]
                  node type: Container [nodeStyle: roundedBox]
                  edge type: uses from: Person to: System
                \(edgeTypes)
                }

                vgraph g: Arch "G" {
                  node customer: Person "Customer";
                  node spa: Container "SPA";
                \(nodes)
                \(edges)
                }
                """)
    }

    @Test("Given a detailing, when connecting a Person to a Container, then uses is offered")
    func connectOffersTheGainedType() throws {
        let s = try session()

        #expect(s.connectCandidates(from: "customer", to: "spa").map { $0.id.id } == ["uses"])
        #expect(s.connectTargets(from: "customer") == ["spa"])

        try s.connect("customer", to: "spa")
        #expect(try s.origin.edgeType(for: s.origin.edges[0]).id.id == "uses")
    }

    /// `pays` reaches Person → Container twice: from System directly and again
    /// through Container's own detailing of Bank.
    @Test("Given types holding a pair several ways, when the menu asks, then each type is listed once")
    func theMenuListsEachTypeOnce() throws {
        let s = try makeTestSession(
            vgl: """
                vnotation Arch {
                  node type: Person [nodeStyle: roundedBox]
                  node type: Bank [nodeStyle: roundedBox, detailedBy: (System, Container)]
                  node type: System [nodeStyle: roundedBox, detailedBy: (Container)]
                  node type: Container [nodeStyle: roundedBox]
                  edge type: uses from: Person to: System
                  edge type: pays from: Person to: Bank
                }

                vgraph g: Arch "G" {
                  node customer: Person "Customer";
                  node spa: Container "SPA";
                }
                """)

        let options = EditorCore.connectOptions(from: "customer", to: "spa", notationBreak: .forbidden, in: s)
        #expect(options.map { $0.id } == ["uses", "pays"])
    }

    @Test("Given an edge to a System, when its end is dragged, then a Container is a target and keeps the type")
    func reattachOffersAGainedPair() throws {
        let s = try session(nodes: "  node shop: System \"Shop\";", edges: "  edge customer -> shop;")
        let edge = s.origin.edges[0].id.id

        #expect(s.reattachCandidates(edge: edge, end: .to, to: "spa").map { $0.id.id } == ["uses"])
        #expect(s.reattachTargets(edge: edge, end: .to) == ["spa"])

        try s.reattach(edge, end: .to, to: "spa")
        #expect(try s.origin.edgeType(for: s.origin.edges[0]).id.id == "uses")
    }

    @Test("Given an edge on a gained pair, when retyping it, then the other gained type is offered and applied")
    func retypeOffersTheOtherGainedType() throws {
        let s = try session(
            edgeTypes: "  edge type: calls from: Person to: System", edges: "  edge customer -> spa: uses;")
        let edge = s.origin.edges[0].id.id

        #expect(s.retypeCandidates(edge: edge).map { $0.id.id } == ["calls"])

        try s.changeType(of: edge, using: EdgeType.Id(string: "calls"))
        #expect(try s.exportVGL().contains("edge customer -> spa: calls"))
    }
}
