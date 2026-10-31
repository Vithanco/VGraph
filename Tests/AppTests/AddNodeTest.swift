// The AddNode command: a node born with no edge at all, in the group the user
// pointed at. See ADR-0016.

import EditorCore
import Testing
import VGLanguage
import VGraph

@testable import App

struct AddNodeTest {
    let vgl = """
        vgraph demo: ConceptMap "Demo" {
          node a: Concept "A";
        }
        """

    private func session() throws -> TestSession {
        try makeTestSession(vgl: vgl)
    }

    /// The plain case: a node with no relationship, at the top level. `nil` is how
    /// a caller with no pointer — the toolbar button — says "top level" without
    /// having to learn the root group's id.
    ///
    /// `concept_2`, not `_1`: ids count from how many of that type already exist,
    /// and `a` is a Concept. The placeholder label is explicit for the reason
    /// ADR-0009 gives — an absent one becomes the node id after export→reparse.
    @Test func addingANodeAtTopLevelCreatesItWithAPlaceholder() throws {
        let s = try session()

        let created = try s.addNode(in: nil, ofType: NodeType(string: "Concept"))
        #expect(created == "concept_2")

        #expect(try s.exportVGL().contains("node concept_2: Concept \"Change Me\""))
    }

    /// The placeholder is a real, explicit label. An absent one reads "Change Me"
    /// in memory and becomes the node id after export→reparse, so the visible text
    /// would change under the user on the next keystroke (ADR-0009).
    @Test func thePlaceholderSurvivesReparse() throws {
        let s = try session()

        #expect(try s.addNode(in: nil, ofType: NodeType(string: "Concept")) == "concept_2")

        let before = try s.origin.get(node: Node(string: "concept_2"), attribute: Attributes.Node.label)
        #expect(before == "Change Me")

        try s.replaceDocument(vgl: try s.exportVGL())
        #expect(
            try s.origin.get(node: Node(string: "concept_2"), attribute: Attributes.Node.label)
                == before)
    }

    /// Naming a group puts the node inside it — the case a right-click within a
    /// boundary lands in, since the boundary rect encloses its interior and so
    /// already resolves to the group.
    @Test func addingANodeToAGroupPutsItInsideThatGroup() throws {
        let s = try makeTestSession(
            vgl: """
                vgraph demo: ConceptMap "Demo" {
                  group g1 "Cluster" {
                    node a: Concept "A";
                  }
                }
                """)

        #expect(try s.addNode(in: "g1", ofType: NodeType(string: "Concept")) == "concept_2")

        #expect(s.origin.group(of: Node(string: "concept_2"))?.id.id == "g1")

        // And emitted *within* the group's braces. Asserting only "before the
        // first }" would pass with the node at the top level, because the
        // exporter emits top-level nodes ahead of groups.
        let exported = try s.exportVGL()
        let groupOpen = exported.range(of: "group g1")
        let node = exported.range(of: "node concept_2")
        let groupClose = exported.range(of: "}")
        #expect(groupOpen != nil && node != nil && groupClose != nil)
        #expect(groupOpen!.upperBound < node!.lowerBound)
        #expect(node!.upperBound < groupClose!.lowerBound)
    }

    private let foldedVGL = """
        vgraph demo: ConceptMap "Demo" {
          folded group g1 "Cluster" {
            node a: Concept "A";
          }
        }
        """

    /// The new node goes inside and the group stays as the author left it.
    /// Unfolding was the earlier rule (ADR-0016); folding is now the author's
    /// alone, in the document and in a view alike.
    @Test func addingIntoAFoldedGroupLeavesItFolded() throws {
        let s = try makeTestSession(vgl: foldedVGL)
        #expect(s.isFolded("g1"))

        #expect(try s.addNode(in: "g1", ofType: NodeType(string: "Concept")) == "concept_2")

        #expect(s.isFolded("g1"))
        #expect(s.origin.group(of: Node(string: "concept_2"))?.id.id == "g1")
    }

    /// The pane needs to *name* the root, not merely recognise it: a blank-space
    /// click resolves to nothing, and a menu cannot be built without a target. It
    /// asks the port rather than hard-coding a constant whose own name says it is
    /// for internal use (ADR-0016).
    @Test func theRootGroupCanBeNamedAndTargeted() throws {
        let s = try session()
        let root = s.rootGroupId()

        #expect(s.kind(of: root) == .group)

        // Naming it explicitly is the same as passing nil.
        #expect(try s.addNode(in: root, ofType: NodeType(string: "Concept")) == "concept_2")
        #expect(s.origin.group(of: Node(string: "concept_2"))?.id.id == root)
        #expect(try s.exportVGL().contains("node concept_2: Concept \"Change Me\""))
    }

    /// The root group is a group, so every group command resolves against it —
    /// which was true *before* it was reachable from a menu, and did something
    /// nobody had defined. Folding has no outside to collapse into and discarding
    /// a diagram is the document's business, so these refuse (ADR-0016).
    @Test func theRootGroupRefusesWhatCannotApplyToIt() throws {
        let s = try session()
        // Normalised first, so "changed nothing" can be checked against the text:
        // an unnormalised document re-exports differently even when untouched.
        try s.replaceDocument(vgl: try s.exportVGL())
        let before = try s.exportVGL()
        let root = s.rootGroupId()

        #expect(throws: VError.self) { try s.toggleFolding(of: root) }
        #expect(throws: VError.self) { try s.delete(root) }
        #expect(throws: VError.self) { try s.setLabel(of: root, to: "Renamed") }
        #expect(throws: VError.self) { try s.setURL(of: root, to: "https://example.com") }
        #expect(throws: VError.self) { try s.removeURL(from: root) }

        #expect(try s.exportVGL() == before, "a refusal changed the document")
        #expect(s.canUndo == false, "a refusal cut an undo step")
    }

    // MARK: - The menu (EditorCore)

    /// First in the group menu: it is the one row that *creates* something, and
    /// the whole reason a user right-clicks blank canvas. The ellipsis follows
    /// "Add URL…" — it usually asks before it acts.
    @Test func theGroupMenuOffersAddNodeFirst() throws {
        #expect(EditorCore.commands(on: .group).first == .addNode)

        let s = try makeTestSession(
            vgl: """
                vgraph demo: ConceptMap "Demo" {
                  group g1 "Cluster" {
                    node a: Concept "A";
                  }
                }
                """)

        let row = EditorCore.menu(for: "g1", in: s).first
        #expect(row?.id == .addNode)
        #expect(row?.title == "Add node…")
        #expect(row?.enabled == true)
    }

    /// The [[Root group]] shares the group menu, so the canvas shows its nine rows
    /// with one live, and adds the settings of the whole diagram: layout direction
    /// is live there too. Deliberate, and the cheapest place to start: filtering
    /// waits until the root has a command list of its own worth writing (ADR-0016).
    @Test func theRootMenuOffersAddNodeAndGreysTheRest() throws {
        let s = try session()

        let rows = EditorCore.menu(for: s.rootGroupId(), in: s)
        #expect(rows.count == 10)
        #expect(rows.filter(\.enabled).map(\.id) == [.addNode, .layoutDirection])
    }

    /// ⌥ must not reach them. A greyed row is reachable when it is greyed
    /// *by the notation*; these do not apply at all, so they are `.notApplicable`
    /// — otherwise holding ⌥ over the canvas would delete the diagram.
    @Test func altDoesNotReachTheRootsGreyedRows() throws {
        let s = try session()

        let rows = EditorCore.menu(for: s.rootGroupId(), in: s, notationBreak: .permitted)
        #expect(rows.filter(\.enabled).map(\.id) == [.addNode, .layoutDirection])
        #expect(
            rows.allSatisfy { $0.id == .addNode || $0.id == .layoutDirection || $0.availability == .notApplicable })
    }

    /// Group-only. A node already offers "Add successor", which is the same wish
    /// with a relationship attached; an edge has no group to put anything in.
    @Test func nodeAndEdgeMenusDoNotOfferAddNode() {
        #expect(!EditorCore.commands(on: .node).contains(.addNode))
        #expect(!EditorCore.commands(on: .edge).contains(.addNode))
    }

    /// The choice is a plain node type, because a node with no edge has no
    /// [[Candidate]] — there is no relationship for the notation to decide. And no
    /// break entry: nothing here breaks a notation, so there is nothing to offer.
    @Test func addNodeOptionsOfferEveryDeclaredType() throws {
        let s = try session()

        // The three ConceptMap declares — see `vgraph describe --notation ConceptMap`.
        let options = EditorCore.addNodeOptions(on: s.rootGroupId(), in: s)
        #expect(options.map(\.title).sorted() == ["Concept", "EmphasizedConcept", "Relation"])
        #expect(options.allSatisfy { !$0.isBreak })
        #expect(!options.contains { $0.id.hasPrefix(NodeType.unknownPrefix) })
    }

    /// Empty when there is no question — the rule `splitOptions`, `retypeOptions`
    /// and `connectOptions` all follow. A Causal Loop Diagram declares one node
    /// type, so asking which one would be a dialog with a single button.
    @Test func aNotationWithOneNodeTypeAsksNothing() throws {
        let s = try makeTestSession(
            vgl: """
                vgraph cld: CLD "Demo" {
                  node s1: Stock "Price";
                }
                """)

        #expect(s.nodeTypes().count == 1)
        #expect(EditorCore.addNodeOptions(on: s.rootGroupId(), in: s).isEmpty)
    }
}
