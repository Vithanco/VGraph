import EditorCore
import Testing
import VGraph

@testable import App

@Suite("Derived edges: the editor cannot reach them")
struct DerivedEdgeSessionTests {
    private func session() throws -> TestSession {
        let s = try makeTestSession(
            vgl: """
                vgraph m: CLD "M" {
                  node A: Stock "A";
                  node h: Stock "h";
                  node C: Stock "C";
                  edge A -> h: same;
                  edge h -> C: same;
                }
                vview v {
                  exclude node h;
                }
                """)
        try s.selectView("v")
        return s
    }

    @Test(
        """
        Given a view that hides a middle node, \
        when the editor lists edge types for connecting two shown nodes, \
        then the derived type is not among them and the model's edge types are unchanged
        """
    )
    func derivedTypeNotOffered() throws {
        let s = try session()
        let before = s.origin.edgeTypes.map { $0.id.id }
        #expect(!s.connectCandidates(from: "A", to: "C").contains { $0.isDerived })
        #expect(s.origin.edgeTypes.map { $0.id.id } == before)
        #expect(!before.contains { $0.hasPrefix(EdgeType.derivedPrefix) })
    }

    @Test("Given a derived edge's stamp, when the session is asked to retype or reattach it, then the command is refused as an unknown edge")
    func cannotRetypeOrReattach() throws {
        let s = try session()
        #expect(s.retypeCandidates(edge: "derived-A-C").isEmpty)
        #expect(throws: VError.self) { try s.changeType(of: "derived-A-C") }
    }

    @Test("Given a derived edge in the session, when it is right-clicked, then no command and no target are offered")
    func rightClickOffersNothing() throws {
        let s = try session()
        #expect(s.origin.resolveCommandTarget(id: "derived-A-C") == nil)
        #expect(EditorCore.rightClick(on: "derived-A-C", holding: Selection(), in: s) == nil)
    }

    @Test(
        """
        Given a view whose display fails, \
        when the session needs the shown graph, \
        then the failure is reported instead of silently showing the whole model
        """
    )
    func failingViewIsReported() throws {
        let s = try GraphSession(
            app: makeTestApp(),
            vgl: """
                vgraph m: CLD "M" {
                  node A: Stock "A";
                  folded group g "G" {
                    node x: Stock "X";
                  }
                }
                vview v {
                  exclude node nothere;
                }
                """,
            versionStore: InMemoryVersionStore(), observer: NullDocumentObserver(),
            display: { (_, _) throws(VError) in throw VError.unknownView("v", available: []) })
        try s.selectView("v")
        #expect(throws: VError.self) { try s.toggleFolding(of: "g") }
    }
}
