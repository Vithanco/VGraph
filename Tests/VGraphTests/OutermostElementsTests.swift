//
//  OutermostElementsTests.swift
//  VGraph
//
//  The canonical form over the group tree that the editor's [[Effective
//  selection]] is built on. See ADR-0018.
//

import Testing
import VGLanguage

@testable import VGraph

@Suite("VGraph.outermostElements(of:)")
struct OutermostElementsTests {

    /// Two top-level nodes, a group of two, and a nested group — enough shape for
    /// every rule to have something to bite on.
    ///
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

    // MARK: - Nothing to collapse

    @Test("Elements with no complete group among them come back unchanged")
    func leavesAnOrdinarySetAlone() throws {
        let g = try graph()

        #expect(g.outermostElements(of: ["a", "b"]) == ["a", "b"])
    }

    @Test("A partly selected group does not promote")
    func aPartialGroupStaysItsParts() throws {
        let g = try graph()

        #expect(g.outermostElements(of: ["c"]) == ["c"])
    }

    @Test("The empty set collapses to nothing")
    func emptyStaysEmpty() throws {
        let g = try graph()

        #expect(g.outermostElements(of: []).isEmpty)
    }

    // MARK: - Promotion

    @Test("A group whose every direct child is present is replaced by itself")
    func aCompleteGroupPromotes() throws {
        let g = try graph()

        #expect(g.outermostElements(of: ["c", "d"]) == ["g1"])
    }

    @Test("Promotion carries the rest of the set with it")
    func promotionLeavesUnrelatedElementsAlone() throws {
        let g = try graph()

        #expect(g.outermostElements(of: ["a", "c", "d"]) == ["a", "g1"])
    }

    @Test("Promotion cascades: a group completed by a promoted subgroup promotes too")
    func promotionReachesAFixpoint() throws {
        let g = try graph()

        // f completes g3, and g3 with e completes g2.
        #expect(g.outermostElements(of: ["e", "f"]) == ["g2"])
    }

    // MARK: - Dropping what is already inside

    @Test("An element inside a selected group drops out")
    func aSelectedGroupSwallowsItsChildren() throws {
        let g = try graph()

        #expect(g.outermostElements(of: ["g1", "c"]) == ["g1"])
    }

    @Test("Dropping reaches through nesting, not just one level")
    func aSelectedGroupSwallowsItsGrandchildren() throws {
        let g = try graph()

        #expect(g.outermostElements(of: ["g2", "f"]) == ["g2"])
    }

    // MARK: - Promotion stops below the root group (ADR-0018)

    /// The root is the one group that cannot be pointed at — a click on blank
    /// canvas clears — so it never belongs in a set the user assembled by
    /// pointing. Promoting into it produced the *canvas* menu for a right-click
    /// on the only node in a diagram, which is how this was found.
    @Test("Selecting every top-level element does not promote to the root")
    func everythingStaysItsParts() throws {
        let g = try graph()

        #expect(g.outermostElements(of: ["a", "b", "g1", "g2"]) == ["a", "b", "g1", "g2"])
    }

    @Test("A cascade that would reach the root stops below it")
    func theCascadeStopsBelowTheRoot() throws {
        let g = try graph()

        #expect(g.outermostElements(of: ["a", "b", "c", "d", "e", "f"]) == ["a", "b", "g1", "g2"])
    }

    /// The one node in a one-node diagram is that node, not the diagram.
    @Test("A lone node is never the whole diagram")
    func aLoneNodeStaysANode() throws {
        let vgl = """
            vgraph demo: ConceptMap "Demo" {
              node only: Concept "Only";
            }
            """
        let g = try VGraphParser(logger: NoOpLogger()).parse(source: vgl)

        #expect(g.outermostElements(of: ["only"]) == ["only"])
    }

    // MARK: - Empty groups

    /// A group holding a node *and* an empty subgroup does not promote when only
    /// the node is chosen. Leaf-coverage would say it does — both sets cover the
    /// same nodes — and would sweep the untouched subgroup into whatever command
    /// runs next. The rule is "all direct children", which is why an empty group
    /// needs no carve-out of its own: it has no children to be present.
    @Test("An empty subgroup keeps its parent from promoting")
    func anEmptySubgroupBlocksPromotion() throws {
        let vgl = """
            vgraph demo: ConceptMap "Demo" {
              group outer "Outer" {
                node n: Concept "N";
                group hollow "Hollow" {
                }
              }
            }
            """
        let g = try VGraphParser(logger: NoOpLogger()).parse(source: vgl)

        #expect(g.outermostElements(of: ["n"]) == ["n"])
    }

    @Test("An empty group never promotes on its own")
    func anEmptyGroupIsNeverInvented() throws {
        let vgl = """
            vgraph demo: ConceptMap "Demo" {
              node a: Concept "A";
              group hollow "Hollow" {
              }
            }
            """
        let g = try VGraphParser(logger: NoOpLogger()).parse(source: vgl)

        #expect(g.outermostElements(of: ["a"]) == ["a"])
    }

    // MARK: - Input the editor should never send, and must survive anyway

    @Test("Ids that name nothing are ignored")
    func unknownIdsAreDropped() throws {
        let g = try graph()

        #expect(g.outermostElements(of: ["a", "no-such-thing"]) == ["a"])
    }

    @Test("Duplicates collapse")
    func duplicatesAreHarmless() throws {
        let g = try graph()

        #expect(g.outermostElements(of: ["a", "a"]) == ["a"])
    }

    @Test("The answer is ordered, so callers and tests can rely on it")
    func theResultIsDeterministic() throws {
        let g = try graph()

        #expect(g.outermostElements(of: ["b", "a"]) == g.outermostElements(of: ["a", "b"]))
    }
}
