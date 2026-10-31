import Testing
import VGLanguage
import VGraph

@testable import App

/// Reattaching an edge end onto a detail retypes the edge by R1 (ADR-0032).
struct ReattachOntoDetailTest {
    private static let containerLevel = "  edge type: containerToContainer from: Container to: Container\n"

    private func session(edge: String, containerLevelType: Bool = true) throws -> TestSession {
        try makeTestSession(
            vgl: """
                vnotation Arch {
                  node type: Person [nodeStyle: roundedBox]
                  node type: System [nodeStyle: roundedBox, detailedBy: (Container)]
                  node type: Container [nodeStyle: roundedBox]
                  edge type: systemToSystem from: System to: System
                \(containerLevelType ? Self.containerLevel : "")}

                vgraph g: Arch "G" {
                  node alice: Person "Alice";
                  node bank: System "Bank";
                  node mail: System "Mail";
                  group ibs: System "Internet Banking" {
                    node api: Container "API";
                    node smtp: Container "SMTP";
                  };
                  // keep this note
                \(edge)
                }
                """)
    }

    private func onlyEdge(_ s: TestSession) throws -> Edge {
        try #require(s.origin.edges.count == 1)
        return s.origin.edges[0]
    }

    private func typeOfOnlyEdge(_ s: TestSession) throws -> String {
        try s.origin.edgeType(for: try onlyEdge(s)).id.id
    }

    @Test(
        "Given an edge from a container to a system, when its second end moves onto a container, then it takes the container-level type and keeps its label"
    )
    func theSecondEndOntoADetailRetypes() throws {
        let s = try session(edge: "  edge api -> mail \"sends via\";")

        try s.reattach(try onlyEdge(s).id.id, end: .to, to: "smtp")

        #expect(try onlyEdge(s).to.id == "smtp")
        #expect(try typeOfOnlyEdge(s) == "containerToContainer")
        let exported = try s.exportVGL()
        #expect(exported.contains("edge api -> smtp \"sends via\""), "\(exported)")
        #expect(exported.contains("// keep this note"), "\(exported)")
    }

    @Test("Given an edge between systems, when its first end moves onto a container, then it keeps its type")
    func theFirstEndOntoADetailKeepsTheType() throws {
        let s = try session(edge: "  edge bank -> mail \"pays\";")

        try s.reattach(try onlyEdge(s).id.id, end: .to, to: "smtp")

        #expect(try onlyEdge(s).to.id == "smtp")
        #expect(try typeOfOnlyEdge(s) == "systemToSystem")
    }

    @Test(
        "Given no type for the container-level pair, when the second end moves onto a container, then the edge is unknown-typed and the quality report says so"
    )
    func noDeclaredTypeMintsUnknownAndStillReattaches() throws {
        let s = try session(edge: "  edge api -> mail \"sends via\";", containerLevelType: false)

        try s.reattach(try onlyEdge(s).id.id, end: .to, to: "smtp")

        #expect(try onlyEdge(s).to.id == "smtp")
        #expect(try typeOfOnlyEdge(s).hasPrefix(EdgeType.unknownPrefix))
        let exported = try s.exportVGL()
        #expect(exported.contains("\"sends via\""), "\(exported)")
        let findings = try makeTestApp().analyzeQuality(exported).messages
            .filter { $0.target == .edge(from: "api", to: "smtp") }
        #expect(findings.contains { $0.message.contains("invalid edge type") }, "\(findings)")
    }

    @Test("Given no type for the new pair, when an end moves onto a node that is not a detail, then nothing changes")
    func aMoveOntoANonDetailWithoutATypeIsRefused() throws {
        let s = try session(edge: "  edge bank -> mail;")
        let before = try s.exportVGL()

        #expect(throws: VError.self) { try s.reattach(try onlyEdge(s).id.id, end: .to, to: "alice") }
        #expect(try s.exportVGL() == before)
    }
}
