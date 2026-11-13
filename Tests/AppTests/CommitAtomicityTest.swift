// A command that cannot be exported must leave the session exactly as it was.
// `commit` exports before it adopts, so the OriginGraph never becomes one the
// exporter refuses — see GraphSession.commit.

import Testing
import VGLanguage
import VGraph

@testable import App

/// Exports like the real exporter until a group is folded, then refuses: the
/// graph a command produces is one the exporter cannot serialise. Only that
/// trigger is refused, so earlier steps can be taken.
private struct RefusesFoldedGroupsExporter: ForExportAGraph {
    func export(graph: VGraph) throws(VError) -> String {
        let text = try VGLExporter().export(graph: graph)
        guard !text.contains("folded") else { throw VError.notImplemented("cannot export folded") }
        return text
    }
}

private struct RefusesFoldedGroupsPorts: AppPorts {
    let logger = NoOpLogger()
    let parser = VGraphParser(logger: NoOpLogger())
    let highlighter = NullHighlighter()
    let renderer = NullRenderer()
    let layoutEngine = NullLayoutEngine()
    let documentExporter = RefusesFoldedGroupsExporter()
}

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

    @Test func unexportableCommandLeavesTheSessionUntouched() throws {
        let s = try VGraphApplication(ports: RefusesFoldedGroupsPorts()).makeSession(vgl: base)
        try s.setLabel(of: "a", to: "Renamed")
        let before = try s.exportVGL()
        let versionBefore = s.currentVersion

        #expect(throws: VError.notImplemented("cannot export folded")) {
            try s.toggleFolding(of: "g1")
        }

        #expect(try s.exportVGL() == before)
        #expect(s.canUndo == true, "the earlier step was lost")
        #expect(s.canRedo == false)
        #expect(s.currentVersion == versionBefore)
        #expect(try s.undo() == base)
    }
}
