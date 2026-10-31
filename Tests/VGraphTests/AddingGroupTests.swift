//
//  AddingGroupTests.swift
//  VGraph
//
//  Making a group out of several elements. See ADR-0018.
//

import Testing
import VGLanguage

@testable import VGraph

@Suite("VGraph.addingGroup and groupingTarget")
struct AddingGroupTests {

    ///     root ── a, b
    ///          └─ g1 ── c, d
    ///          └─ g2 ── e
    ///                └─ g3 ── f
    private func graph() throws -> VGraph {
        let vgl = """
            vgraph demo: ConceptMap "Demo" {
              node a: Concept "A";
              node b: Concept "B";
              group g1 "G1" {
                node c: Concept "C";
                node d: Concept "D";
              }
              group g2 "G2" {
                node e: Concept "E";
                group g3 "G3" {
                  node f: Concept "F";
                }
              }
              edge a -> b;
            }
            """
        return try VGraphParser(logger: NoOpLogger()).parse(source: vgl)
    }

    // MARK: - Where a new group would go

    @Test("Elements sharing a parent group there, with nothing detached")
    func siblingsGroupCleanly() throws {
        let g = try graph()

        let target = g.groupingTarget(for: ["a", "b"])

        #expect(target?.parentId == rootGroup)
        #expect(target?.detached == 0)
    }

    @Test("Elements inside a boundary group inside it")
    func siblingsInsideABoundaryStayThere() throws {
        let g = try graph()

        let target = g.groupingTarget(for: ["c"])

        #expect(target?.parentId == "g1")
        #expect(target?.detached == 0)
    }

    @Test("Elements from different parents report what would have to move")
    func crossingBoundariesCountsTheDetachments() throws {
        let g = try graph()

        let target = g.groupingTarget(for: ["a", "c"])

        #expect(target?.parentId == rootGroup)
        #expect(target?.detached == 1)
    }

    @Test("Nothing selected is nothing to group")
    func anEmptySetHasNoTarget() throws {
        let g = try graph()

        #expect(g.groupingTarget(for: []) == nil)
    }

    /// The whole diagram collapses to the [[Root group]], which has no outside to
    /// be wrapped in. `nil` here is what greys the menu row (ADR-0016, ADR-0018).
    @Test("The root group cannot be grouped")
    func theRootHasNoTarget() throws {
        let g = try graph()

        // The diagram cannot be wrapped, but its contents can — and that is what
        // "select everything, then group" means. Found in the browser: on a
        // two-node diagram, selecting both nodes *is* selecting everything, so
        // refusing here greyed the button in the commonest case there is.
        let target = g.groupingTarget(for: ["a", "b", "g1", "g2"])
        #expect(target?.parentId == rootGroup)
        #expect(target?.detached == 0)
    }

    @Test("Grouping everything wraps the diagram's contents")
    func groupingEverythingWrapsTheContents() throws {
        let g = try graph()

        let (changed, created) = try g.addingGroup(of: ["a", "b", "g1", "g2"], detaching: false)

        #expect(changed.parentGroup(of: created) == Group(rawValue: rootGroup))
        #expect(changed.group(of: Node("a")) == created)
        #expect(changed.parentGroup(of: Group(rawValue: "g1")) == created)
        // One level of nesting, not two: the members are the root's children.
        #expect(changed.group(of: Node("c")) == Group(rawValue: "g1"))
    }

    @Test("An empty diagram still has nothing to group")
    func anEmptyDiagramHasNoTarget() throws {
        let vgl = """
            vgraph demo: ConceptMap "Demo" {
            }
            """
        let g = try VGraphParser(logger: NoOpLogger()).parse(source: vgl)

        #expect(g.groupingTarget(for: [rootGroup]) == nil)
    }

    @Test("One element is a legitimate group of one")
    func aSingleElementCanBeWrapped() throws {
        let g = try graph()

        #expect(g.groupingTarget(for: ["a"])?.detached == 0)
    }

    /// Grouping can never empty a group, and the reason is a proof rather than a
    /// precaution: a group is emptied only if *every* direct child moves, every
    /// child moving means every child was chosen, and every child chosen is
    /// exactly the promotion condition — so the group itself becomes the member
    /// and its children drop out. The damage is always one level ahead of itself.
    ///
    /// Both halves are here. Take `f` alone and `g3` promotes and moves, leaving
    /// `g2` holding `e` — thinned, not emptied. Reach for `e` as well, so that
    /// `g2` *would* be emptied, and `g2` promotes instead and moves whole.
    @Test("Grouping can never empty a group, because promotion gets there first")
    func promotionForestallsEmptying() throws {
        let g = try graph()

        #expect(g.outermostElements(of: ["a", "f"]) == ["a", "g3"])
        #expect(g.groupingTarget(for: ["a", "f"])?.detached == 1)

        #expect(g.outermostElements(of: ["a", "e", "f"]) == ["a", "g2"])
        #expect(g.groupingTarget(for: ["a", "e", "f"])?.detached == 0)
    }

    /// The same thing said about the graph rather than the set: after any
    /// grouping, every group that survives still holds something.
    @Test("No group is left empty by grouping")
    func noGroupIsLeftEmpty() throws {
        let g = try graph()

        for ids in [["a", "f"], ["a", "e", "f"], ["a", "c"], ["c", "e"], ["b", "d", "f"]] {
            let (changed, _) = try g.addingGroup(of: ids, detaching: true)
            for group in changed.groups {
                #expect(!changed.directChildIds(of: group).isEmpty, "\(group.id.id) emptied by \(ids)")
            }
        }
    }

    // MARK: - Making the group

    @Test("The new group holds the elements and carries a placeholder label")
    func createsTheGroupWithItsMembers() throws {
        let g = try graph()

        let (changed, created) = try g.addingGroup(of: ["a", "b"], detaching: false)

        #expect(created.id.id == "group_4")
        #expect(changed.group(of: Node("a")) == created)
        #expect(changed.group(of: Node("b")) == created)
        #expect(created.getName(in: changed) == "Change Me")
    }

    @Test("The new group is a child of the parent the elements shared")
    func sitsInsideTheSharedParent() throws {
        let g = try graph()

        let (changed, created) = try g.addingGroup(of: ["c"], detaching: false)

        #expect(changed.parentGroup(of: created) == Group(rawValue: "g1"))
    }

    @Test("A group can be wrapped, not only nodes")
    func takesGroupsAsMembers() throws {
        let g = try graph()

        let (changed, created) = try g.addingGroup(of: ["a", "g1"], detaching: false)

        #expect(changed.parentGroup(of: Group(rawValue: "g1")) == created)
    }

    // MARK: - Detaching

    @Test("The strict form refuses to pull an element out of its group")
    func strictRefusesToDetach() throws {
        let g = try graph()

        #expect(throws: VError.self) {
            _ = try g.addingGroup(of: ["a", "c"], detaching: false)
        }
    }

    @Test("The permissive form moves it, and leaves the group it came from standing")
    func detachingMovesAndLeavesTheOldGroup() throws {
        let g = try graph()

        let (changed, created) = try g.addingGroup(of: ["a", "c"], detaching: true)

        #expect(changed.group(of: Node("c")) == created)
        #expect(changed.has(group: Group(rawValue: "g1")))
        #expect(changed.group(of: Node("d")) == Group(rawValue: "g1"))
    }

    // MARK: - What comes for free

    /// An edge is in the innermost group holding both its ends, computed on
    /// demand (ADR-0017), so grouping two connected nodes puts their edge in the
    /// new group without `addingGroup` touching it.
    @Test("An edge between two grouped nodes follows them in")
    func edgesFollowTheirEndpoints() throws {
        let g = try graph()

        let (changed, created) = try g.addingGroup(of: ["a", "b"], detaching: false)

        let edge = changed.edges.first { $0.from == Node("a") && $0.to == Node("b") }
        #expect(edge != nil)
        #expect(changed.group(of: edge!.id) == created)
    }

    @Test("The group survives an export and reparse with its members inside it")
    func roundTripsThroughVGL() throws {
        let g = try graph()

        let (changed, created) = try g.addingGroup(of: ["a", "b"], detaching: false)
        let vgl = try VGLExporter().export(graph: changed)
        let reparsed = try VGraphParser(logger: NoOpLogger()).parse(source: vgl)

        #expect(reparsed.has(group: created))
        #expect(reparsed.group(of: Node("a")) == created)
        #expect(reparsed.group(of: Node("b")) == created)
    }

    // MARK: - Ids

    @Test("A new group id avoids everything already in the keyspace")
    func mintsAFreeId() throws {
        let vgl = """
            vgraph demo: ConceptMap "Demo" {
              node group_1: Concept "Awkward";
            }
            """
        let g = try VGraphParser(logger: NoOpLogger()).parse(source: vgl)

        #expect(g.newGroupId() == Group(rawValue: "group_2"))
    }
}
