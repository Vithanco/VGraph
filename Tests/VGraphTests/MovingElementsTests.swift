//
//  MovingElementsTests.swift
//  VGraph
//
//  Changing which group an element belongs to. See ADR-0019.
//

import Testing
import VGLanguage

@testable import VGraph

@Suite("VGraph.moving(_:into:)")
struct MovingElementsTests {

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
            }
            """
        return try VGraphParser(logger: NoOpLogger()).parse(source: vgl)
    }

    // MARK: - Moving in

    @Test("A top-level node joins a boundary")
    func aNodeMovesIntoAGroup() throws {
        let g = try graph()

        let changed = try g.moving(["a"], into: "g1")

        #expect(changed.group(of: Node("a")) == Group(rawValue: "g1"))
    }

    @Test("A group joins another group")
    func aGroupMovesIntoAGroup() throws {
        let g = try graph()

        let changed = try g.moving(["g1"], into: "g2")

        #expect(changed.parentGroup(of: Group(rawValue: "g1")) == Group(rawValue: "g2"))
    }

    @Test("Several elements move together")
    func aWholeSetMoves() throws {
        let g = try graph()

        let changed = try g.moving(["a", "b"], into: "g1")

        #expect(changed.group(of: Node("a")) == Group(rawValue: "g1"))
        #expect(changed.group(of: Node("b")) == Group(rawValue: "g1"))
    }

    // MARK: - Moving out, which is moving into the root

    /// "Out" is not a direction. The canvas is the [[Root group]], so leaving a
    /// boundary is joining the group outside it (ADR-0016, ADR-0019).
    @Test("Moving to the root group is how an element leaves a boundary")
    func movingOutIsMovingIntoTheRoot() throws {
        let g = try graph()

        let changed = try g.moving(["c"], into: rootGroup)

        #expect(changed.group(of: Node("c")) == Group(rawValue: rootGroup))
    }

    @Test("Out of a nested group means into the enclosing one")
    func movingOutOneLevelLandsInTheParent() throws {
        let g = try graph()

        let changed = try g.moving(["f"], into: "g2")

        #expect(changed.group(of: Node("f")) == Group(rawValue: "g2"))
    }

    // MARK: - The cycle guard

    /// The model has allowed a cyclic group tree since it was written — nothing
    /// could reach it until moving arrived. `isParent` recurses, so an unguarded
    /// move does not throw, it hangs.
    @Test("A group cannot move into its own descendant")
    func aGroupCannotMoveIntoItsDescendant() throws {
        let g = try graph()

        #expect(throws: VError.self) {
            _ = try g.moving(["g2"], into: "g3")
        }
    }

    @Test("A group cannot move into itself")
    func aGroupCannotMoveIntoItself() throws {
        let g = try graph()

        #expect(throws: VError.self) {
            _ = try g.moving(["g1"], into: "g1")
        }
    }

    /// The guard has to survive the graph it would corrupt: after a refused move
    /// the structure is still walkable, which is the assertion that would hang if
    /// the cycle had been written.
    @Test("A refused move leaves the group tree intact")
    func arefusedMoveChangesNothing() throws {
        let g = try graph()

        _ = try? g.moving(["g2"], into: "g3")

        #expect(g.parentGroup(of: Group(rawValue: "g3")) == Group(rawValue: "g2"))
        #expect(g.groupStructure.isParent(parent: Group(rawValue: "g2"), child: Group(rawValue: "g3")))
    }

    // MARK: - The other refusals

    @Test("Moving into the group it already occupies is refused")
    func movingNowhereIsRefused() throws {
        let g = try graph()

        #expect(throws: VError.self) {
            _ = try g.moving(["c"], into: "g1")
        }
    }

    @Test("The root group cannot be moved")
    func theRootCannotMove() throws {
        let g = try graph()

        #expect(throws: VError.self) {
            _ = try g.moving([rootGroup], into: "g1")
        }
    }

    @Test("Moving nothing is refused")
    func movingNothingIsRefused() throws {
        let g = try graph()

        #expect(throws: VError.self) {
            _ = try g.moving([], into: "g1")
        }
    }

    @Test("A destination that names nothing is refused")
    func anUnknownDestinationIsRefused() throws {
        let g = try graph()

        #expect(throws: VError.self) {
            _ = try g.moving(["a"], into: "no-such-group")
        }
    }

    /// A mixed set is refused whole rather than moving the half that could — a
    /// command that half-succeeds is one the caller cannot undo in one step.
    @Test("One illegal member refuses the whole move")
    func aMixedSetIsRefusedEntirely() throws {
        let g = try graph()

        #expect(throws: VError.self) {
            _ = try g.moving(["a", "g2"], into: "g3")
        }
    }

    // MARK: - What follows from the move

    /// Same rule `delete` follows (ADR-0018), chosen over exempting move so that
    /// one rule stays one rule.
    @Test("Emptying a boundary by moving its last child deletes the boundary")
    func emptyingByMovingDeletesTheGroup() throws {
        let g = try graph()

        let changed = try g.moving(["f"], into: rootGroup)

        #expect(!changed.has(group: Group(rawValue: "g3")))
        #expect(changed.has(group: Group(rawValue: "g2")))
    }

    @Test("The cascade reaches upward, as it does for delete")
    func emptyingCascades() throws {
        let g = try graph()

        let changed = try g.moving(["e", "f"], into: rootGroup)

        #expect(!changed.has(group: Group(rawValue: "g3")))
        #expect(!changed.has(group: Group(rawValue: "g2")))
    }

    /// An edge is in the innermost group holding both its ends (ADR-0017), so it
    /// follows the nodes without `moving` touching it.
    @Test("An edge follows its endpoints")
    func edgesFollowTheirEndpoints() throws {
        let vgl = """
            vgraph demo: ConceptMap "Demo" {
              node a: Concept "A";
              node b: Concept "B";
              group box "Box" {
                node inside: Concept "Inside";
              }
              edge a -> b;
            }
            """
        let g = try VGraphParser(logger: NoOpLogger()).parse(source: vgl)

        let changed = try g.moving(["a", "b"], into: "box")

        let edge = changed.edges.first { $0.from == Node("a") && $0.to == Node("b") }
        #expect(changed.group(of: edge!.id) == Group(rawValue: "box"))
    }

    @Test("A move survives an export and reparse")
    func roundTripsThroughVGL() throws {
        let g = try graph()

        let changed = try g.moving(["a"], into: "g1")
        let vgl = try VGLExporter().export(graph: changed)
        let reparsed = try VGraphParser(logger: NoOpLogger()).parse(source: vgl)

        #expect(reparsed.group(of: Node("a")) == Group(rawValue: "g1"))
    }

    // MARK: - Where a set may go

    @Test("Destinations exclude the current parent and the element itself")
    func destinationsLeaveOutTheUselessOnes() throws {
        let g = try graph()

        let destinations = g.moveDestinations(for: ["c"])

        #expect(!destinations.contains("g1"))
        #expect(destinations.contains(rootGroup))
        #expect(destinations.contains("g2"))
    }

    @Test("A group's own descendants are not destinations")
    func destinationsExcludeDescendants() throws {
        let g = try graph()

        let destinations = g.moveDestinations(for: ["g2"])

        #expect(!destinations.contains("g2"))
        #expect(!destinations.contains("g3"))
        #expect(destinations.contains("g1"))
    }

    @Test("Every destination is one the command accepts")
    func destinationsAgreeWithTheCommand() throws {
        let g = try graph()

        for ids in [["a"], ["c"], ["g1"], ["g3"], ["a", "b"]] {
            for destination in g.moveDestinations(for: ids) {
                #expect(throws: Never.self) { _ = try g.moving(ids, into: destination) }
            }
        }
    }

    @Test("The root has nowhere to go")
    func theRootHasNoDestinations() throws {
        let g = try graph()

        #expect(g.moveDestinations(for: [rootGroup]).isEmpty)
    }
}
