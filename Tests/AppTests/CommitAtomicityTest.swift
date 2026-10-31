// A command that cannot be exported must leave the session exactly as it was.
// `commit` exports before it adopts, so the OriginGraph never becomes one the
// exporter refuses — see GraphSession.commit.

import Testing
import VGLanguage
import VGraph

@testable import App

struct CommitAtomicityTest {
    let base = """
        vgraph demo: ConceptMap "Demo" {
          group g1 "Cluster" {
            node a: Concept "A";
            node b: Concept "B";
            edge a -> b;
          }
          node c: Concept "C";
        }
        """

    /// Deleting the root group is the reachable way to build a graph the
    /// exporter cannot serialise: the elements survive with nothing to hold
    /// them, and the export throws on the missing group.
    @Test func unexportableCommandLeavesTheSessionUntouched() throws {
        let s = try makeTestSession(vgl: base)
        let initial = try s.exportVGL()
        try s.toggleFolding(of: "g1")  // one step of history to preserve
        let before = try s.exportVGL()
        let nodesBefore = s.origin.nodes.count

        #expect(throws: VError.self) { try s.delete(rootGroup) }

        // The refusal changed nothing: origin still exports, and to the same text.
        #expect(try s.exportVGL() == before)
        #expect(s.origin.nodes.count == nodesBefore)
        #expect(s.canUndo == true)
        #expect(s.canRedo == false)

        // And the session still works — the failed command left no wreckage.
        #expect(try s.undo() == base)
        #expect(try s.exportVGL() == initial)
    }
}
