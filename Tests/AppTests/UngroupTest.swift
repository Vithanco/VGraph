// Taking a group apart, and taking it away. Two commands because they are two
// intentions: Ungroup is grouping's inverse, Delete is destruction.
// See ADR-0018.

import EditorCore
import Testing
import VGraph

@testable import App

struct UngroupTest {
    ///     root ── a
    ///          └─ g1 ── c, d
    ///                └─ g2 ── e
    let vgl = """
        vgraph demo: ConceptMap "Demo" {
          node a: Concept "A";
          group g1 "G1" {
            node c: Concept "C";
            node d: Concept "D";
            group g2 "G2" {
              node e: Concept "E";
            }
          }
        }
        """

    private func session() throws -> TestSession {
        try makeTestSession(vgl: vgl)
    }

    // MARK: - Ungroup: the box goes, the contents stay

    @Test func ungroupingRemovesTheBoxAndKeepsTheContents() throws {
        let s = try session()

        try s.ungroup("g1")

        #expect(!s.origin.has(group: Group(rawValue: "g1")))
        #expect(s.origin.has(node: Node("c")))
        #expect(s.origin.has(node: Node("d")))
    }

    /// The contents move up one level, to where the group itself was.
    @Test func theContentsRiseToTheParent() throws {
        let s = try session()

        try s.ungroup("g1")

        #expect(s.origin.group(of: Node("c")) == Group(rawValue: rootGroup))
        #expect(s.origin.parentGroup(of: Group(rawValue: "g2")) == Group(rawValue: rootGroup))
    }

    @Test func aNestedGroupIsUngroupedIntoItsParent() throws {
        let s = try session()

        try s.ungroup("g2")

        #expect(s.origin.group(of: Node("e")) == Group(rawValue: "g1"))
        #expect(s.origin.has(group: Group(rawValue: "g1")))
    }

    /// The point of having it: everything survives the round trip, which is what
    /// the old `delete` on a group failed to do.
    @Test func nothingIsLostOnExport() throws {
        let s = try session()

        try s.ungroup("g1")
        let vgl = try s.exportVGL()

        #expect(vgl.contains("node c:"))
        #expect(vgl.contains("node d:"))
        #expect(vgl.contains("node e:"))
        #expect(!vgl.contains("group g1"))
    }

    @Test func ungroupingIsGroupingsInverse() throws {
        let s = try session()
        let before = try s.exportVGL()

        let created = try s.addGroup(containing: ["c", "d"])
        try s.ungroup(created!)

        #expect(try s.exportVGL() == before)
    }

    @Test func theRootGroupCannotBeUngrouped() throws {
        let s = try session()

        #expect(throws: VError.self) { try s.ungroup(s.rootGroupId()) }
    }

    @Test func onlyAGroupCanBeUngrouped() throws {
        let s = try session()

        #expect(throws: VError.self) { try s.ungroup("a") }
    }

    // MARK: - Delete: the box and everything in it

    /// The other intention, and the fix for a command that used to lose the
    /// contents without deleting them — they left the group structure, so the
    /// exporter stopped writing them and they vanished at the next reparse.
    @Test func deletingAGroupTakesItsContentsWithIt() throws {
        let s = try session()

        try s.delete("g1")

        #expect(!s.origin.has(group: Group(rawValue: "g1")))
        #expect(!s.origin.has(group: Group(rawValue: "g2")))
        #expect(!s.origin.has(node: Node("c")))
        #expect(!s.origin.has(node: Node("e")))
        #expect(s.origin.has(node: Node("a")))
    }

    @Test func whatSurvivesADeleteIsWhatIsExported() throws {
        let s = try session()

        try s.delete("g1")
        let vgl = try s.exportVGL()

        #expect(vgl.contains("node a:"))
        #expect(!vgl.contains("node c:"))
        #expect(!vgl.contains("node e:"))
    }

    /// Deleting a group can empty its parent, and the cleanup rule applies to
    /// that exactly as it does to deleting a node.
    @Test func deletingTheOnlyChildGroupRemovesTheParentToo() throws {
        let s = try makeTestSession(
            vgl: """
                vgraph demo: ConceptMap "Demo" {
                  node a: Concept "A";
                  group outer "Outer" {
                    group inner "Inner" {
                      node f: Concept "F";
                    }
                  }
                }
                """)

        try s.delete("inner")

        #expect(!s.origin.has(group: Group(rawValue: "outer")))
        #expect(s.origin.has(node: Node("a")))
    }

    // MARK: - History

    @Test func bothAreOneUndoStep() throws {
        let s = try session()
        let before = try s.exportVGL()

        try s.ungroup("g1")
        _ = try s.undo()
        #expect(try s.exportVGL() == before)

        try s.delete("g1")
        _ = try s.undo()
        #expect(try s.exportVGL() == before)
    }
}
