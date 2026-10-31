// Making a group of several elements, from the diagram pane's port.
// See ADR-0018.

import EditorCore
import Testing
import VGraph

@testable import App

struct AddGroupTest {
    ///     root ── a, b
    ///          └─ g1 ── c, d
    let vgl = """
        vgraph demo: ConceptMap "Demo" {
          node a: Concept "A";
          node b: Concept "B";
          group g1 "G1" {
            node c: Concept "C";
            node d: Concept "D";
          }
        }
        """

    private func session() throws -> TestSession {
        try makeTestSession(vgl: vgl)
    }

    // MARK: - The queries the menu is built from

    @Test func theSessionCollapsesCompleteGroupsUpward() throws {
        let s = try session()

        #expect(s.outermostElements(of: ["c", "d"]) == ["g1"])
    }

    @Test func theSessionReportsWhereANewGroupWouldGo() throws {
        let s = try session()

        #expect(s.groupingTarget(for: ["a", "b"])?.parentId == s.rootGroupId())
        #expect(s.groupingTarget(for: ["a", "b"])?.detached == 0)
    }

    /// Selecting everything collapses to the [[Root group]], which cannot be
    /// wrapped — but its contents can, and that is what the user meant.
    @Test func groupingTheWholeDiagramWrapsItsContents() throws {
        let s = try session()

        #expect(s.groupingTarget(for: ["a", "b", "g1"])?.parentId == s.rootGroupId())
        #expect(s.groupingTarget(for: ["a", "b", "g1"])?.detached == 0)
    }

    // MARK: - The command

    /// The id comes back so the editor can select the new group and open an
    /// [[Inline edit]] on its placeholder label — `addNode`'s path, unchanged
    /// (ADR-0016, ADR-0009).
    @Test func groupingReturnsTheNewGroupToNameIt() throws {
        let s = try session()

        let created = try s.addGroup(containing: ["a", "b"])

        #expect(created == "group_2")
        #expect(try s.exportVGL().contains("group group_2 \"Change Me\""))
    }

    @Test func theMembersMoveInside() throws {
        let s = try session()

        _ = try s.addGroup(containing: ["a", "b"])

        #expect(s.origin.group(of: Node("a")) == Group(rawValue: "group_2"))
        #expect(s.origin.group(of: Node("b")) == Group(rawValue: "group_2"))
    }

    @Test func aCompleteGroupIsWrappedRatherThanItsMembers() throws {
        let s = try session()

        let created = try s.addGroup(containing: ["c", "d"])

        #expect(s.origin.parentGroup(of: Group(rawValue: "g1")) == Group(rawValue: created!))
        #expect(s.origin.group(of: Node("c")) == Group(rawValue: "g1"))
    }

    // MARK: - The strict and the permissive form

    @Test func theStrictFormRefusesToDetach() throws {
        let s = try session()

        #expect(throws: VError.self) {
            _ = try s.addGroup(containing: ["a", "c"])
        }
    }

    @Test func thePermissiveFormDetaches() throws {
        let s = try session()

        let created = try s.addGroup(moving: ["a", "c"])

        #expect(s.origin.group(of: Node("c")) == Group(rawValue: created!))
        #expect(s.origin.group(of: Node("d")) == Group(rawValue: "g1"))
    }

    // MARK: - Refusals

    /// Naming the [[Root group]] outright means the same as selecting
    /// everything: the diagram is not wrapped, its contents are.
    @Test func namingTheRootGroupsItsContents() throws {
        let s = try session()

        let created = try s.addGroup(containing: [s.rootGroupId()])

        #expect(s.origin.group(of: Node("a")) == Group(rawValue: created!))
        #expect(s.origin.parentGroup(of: Group(rawValue: "g1")) == Group(rawValue: created!))
    }

    /// What is left of the refusal: a diagram with nothing in it. The domain
    /// throws and `EditorCore` greys the row (ADR-0013's split).
    @Test func anEmptyDiagramHasNothingToGroup() throws {
        let s = try makeTestSession(vgl: "vgraph demo: ConceptMap \"Demo\" {\n}")

        #expect(throws: VError.self) {
            _ = try s.addGroup(containing: [s.rootGroupId()])
        }
    }

    @Test func groupingNothingIsRefused() throws {
        let s = try session()

        #expect(throws: VError.self) {
            _ = try s.addGroup(containing: [])
        }
    }

    // MARK: - History

    /// One command is one [[Snapshot]], so a single undo takes back the group
    /// *and* the moves that filled it — which is what makes the detaching form
    /// safe enough to need no confirmation.
    @Test func groupingIsOneUndoStep() throws {
        let s = try session()
        let before = try s.exportVGL()

        _ = try s.addGroup(moving: ["a", "c"])
        #expect(s.canUndo)

        _ = try s.undo()
        #expect(try s.exportVGL() == before)
    }
}
