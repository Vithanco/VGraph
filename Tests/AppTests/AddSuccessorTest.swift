// The AddSuccessor / AddPredecessor commands, and with them the multi-step
// VCommand conversation. See ADR-0013.

import EditorCore
import Testing
import VGLanguage
import VGraph

@testable import App

struct AddSuccessorTest {
    let vgl = """
        vgraph demo: ConceptMap "Demo" {
          node a: Concept "A";
        }
        """

    private func session() throws -> TestSession {
        try makeTestSession(vgl: vgl)
    }

    /// The whole conversation: one choice, then a node and an edge. A Concept has
    /// one relationship leaving it, so the list is that candidate plus the
    /// notation-break escape. Naming happens afterwards, as an [[Inline edit]].
    @Test func choosingACandidateCreatesNodeAndEdge() throws {
        let s = try session()

        let options = EditorCore.relatedOptions(from: "a", outgoing: true, in: s)
        #expect(options.map(\.title) == ["Relation", "Other type…"])

        let created = try s.addSuccessor(from: "a", using: EdgeType.Id(string: "concept_to_relation"))
        #expect(created == "relation_1")

        let exported = try s.exportVGL()
        #expect(exported.contains("node relation_1: Relation \"Change Me\""))
        #expect(exported.contains("edge a -> relation_1"))
    }

    /// The command never asks for text: it creates the node with the placeholder
    /// and hands it back for an [[Inline edit]]. The placeholder must be an
    /// *explicit* label — an absent one reads "Change Me" in memory but becomes the
    /// node id after export→reparse, so the visible text would change on the next
    /// keystroke (ADR-0009).
    @Test func createdNodeCarriesAPlaceholderThatSurvivesReparse() throws {
        let s = try session()

        #expect(
            try s.addSuccessor(from: "a", using: EdgeType.Id(string: "concept_to_relation"))
                == "relation_1")

        let before = try s.origin.get(node: Node(string: "relation_1"), attribute: Attributes.Node.label)
        #expect(before == "Change Me")

        try s.replaceDocument(vgl: try s.exportVGL())
        let after = try s.origin.get(node: Node(string: "relation_1"), attribute: Attributes.Node.label)
        #expect(after == before)
    }

    /// The command names the node it created so the adapter can open an
    /// [[Inline edit]] on it — the editor has the new graph but no other way to
    /// know which node is new.
    @Test func addSuccessorHandsBackTheNodeToEdit() throws {
        let s = try session()

        #expect(
            try s.addSuccessor(from: "a", using: EdgeType.Id(string: "concept_to_relation"))
                == "relation_1")
    }

    /// A junctor is icon-only, so no inline editor is offered — `edit` is nil.
    /// It still carries the placeholder like every other created node: omitting the
    /// label would reintroduce the reparse mismatch, invisibly rather than not at
    /// all (ADR-0009).
    @Test func aTypeThatDisplaysNoLabelGetsNoInlineEditor() throws {
        let s = try makeTestSession(
            vgl: """
                vgraph crt: CRT "Demo" {
                  node u: UndesirableEffect "Sales are falling";
                }
                """)

        // nil, not an id: an icon-only type has nothing to open an editor on.
        #expect(
            try s.addSuccessor(from: "u", using: EdgeType.Id(string: "undesirable_to_and_junctor"))
                == nil)

        let exported = try s.exportVGL()
        #expect(exported.contains("node andjunctor_1: AndJunctor \"Change Me\""))
        #expect(exported.contains("edge u -> andjunctor_1"))
    }

    /// "Other type…" opens the full node-type list and joins two types the
    /// notation does not connect. The break must be *visible*: the edge falls to
    /// an unknown edge type, which renders red and raises a quality warning.
    ///
    /// `concept_2`, not `_1`: ids start counting from how many of that type
    /// exist, and `a` is already a Concept. See `NewNodeIdTests`.
    @Test func otherTypeBreaksTheNotationVisibly() throws {
        let s = try session()

        // "Other type…" opens the full node-type list — the editor's second
        // question, which `breakTypeOptions` supplies.
        #expect(EditorCore.breakTypeOptions(in: s).contains { $0.id == "Concept" })

        let created = try s.addSuccessor(from: "a", ofType: NodeType(string: "Concept"))
        #expect(created == "concept_2")

        #expect(try s.exportVGL().contains("node concept_2: Concept \"Change Me\""))
        #expect(!GenericQualityChecks.unknownEdgeTypes(graph: s.origin).isEmpty)
    }

    /// The new node joins whatever group its source lives in.
    @Test func newNodeInheritsTheSourcesGroup() throws {
        let s = try makeTestSession(
            vgl: """
                vgraph demo: ConceptMap "Demo" {
                  group g1 "Cluster" {
                    node a: Concept "A";
                  }
                }
                """)

        #expect(
            try s.addSuccessor(from: "a", using: EdgeType.Id(string: "concept_to_relation"))
                == "relation_1")

        #expect(s.origin.group(of: Node(string: "relation_1"))?.id.id == "g1")

        // And it survives the export: emitted within the group's braces, not
        // after them. Bounded on *both* sides — the exporter writes top-level
        // nodes before groups, so "before the first }" alone holds even for a
        // node that regressed to the top level.
        let exported = try s.exportVGL()
        let groupStart = try #require(exported.range(of: "group g1"))
        let newNode = try #require(exported.range(of: "node relation_1"))
        let groupEnd = try #require(exported.range(of: "}", range: groupStart.upperBound..<exported.endIndex))
        #expect(groupStart.upperBound < newNode.lowerBound)
        #expect(newNode.upperBound < groupEnd.lowerBound)
    }

    /// The predecessor direction builds the same node but reverses the edge.
    @Test func addPredecessorReversesTheEdge() throws {
        let s = try makeTestSession(
            vgl: """
                vgraph demo: ConceptMap "Demo" {
                  node r: Relation "leads to";
                }
                """)

        #expect(
            try s.addPredecessor(to: "r", using: EdgeType.Id(string: "concept_to_relation"))
                == "concept_1")

        let exported = try s.exportVGL()
        #expect(exported.contains("node concept_1: Concept \"Change Me\""))
        #expect(exported.contains("edge concept_1 -> r"))
    }

    /// Ids are unique across the *shared* node/edge/group keyspace, not just among
    /// nodes — so a group already called `relation_1` pushes the new node to
    /// `relation_2`. Narrowing the check to nodes alone would produce a document
    /// that no longer parses.
    @Test func newNodeIdSkipsIdsTakenByOtherElementKinds() throws {
        let s = try makeTestSession(
            vgl: """
                vgraph demo: ConceptMap "Demo" {
                  group relation_1 "Taken" {
                    node a: Concept "A";
                  }
                }
                """)

        #expect(
            try s.addSuccessor(from: "a", using: EdgeType.Id(string: "concept_to_relation"))
                == "relation_2")

        let exported = try s.exportVGL()
        #expect(exported.contains("node relation_2: Relation \"Change Me\""))
        // Round-trips: a colliding id would have failed the reparse.
        try s.replaceDocument(vgl: exported)
    }

    /// The ways the command declines. Each leaves the graph alone, so a stale
    /// menu click is harmless.
    @Test func addingDeclinesUnknownDisabledAndMismatchedTargets() throws {
        let s = try session()
        // Normalised first, so "changed nothing" can be checked against history
        // too: an unnormalised document re-exports differently even when the
        // graph is untouched, and the no-op guard rightly cannot tell that from
        // a real edit.
        try s.replaceDocument(vgl: try s.exportVGL())
        let before = try s.exportVGL()

        // An edge type the notation does not offer used to be a *silent* no-op,
        // inherited from the generic path: the command is available, so nothing
        // rejected the call, and it simply matched no candidate. It refuses now
        // — see `NamedCommandOptionRefusalTest` — and still changes nothing.
        #expect(
            throws: VError.commandOptionNotOffered(.addSuccessor, target: "a", option: "nope")
        ) {
            try s.addSuccessor(from: "a", using: EdgeType.Id(string: "nope"))
        }
        #expect(try s.exportVGL() == before)
        #expect(s.canUndo == false, "a refusal cut an undo step")

        // Unknown target id.
        #expect(throws: VError.self) { try s.addSuccessor(from: "ghost", using: EdgeType.Id(string: "concept_to_relation")) }

        // Kind mismatch: addSuccessor is node-only, and an edge endpoint may never
        // be a group, so a group target must not resolve.
        let grouped = try makeTestSession(
            vgl: """
                vgraph demo: ConceptMap "Demo" {
                  group g1 "Cluster" {
                    node a: Concept "A";
                  }
                }
                """)
        #expect(throws: VError.self) { try grouped.addSuccessor(from: "g1", using: EdgeType.Id(string: "concept_to_relation")) }

        // Enabled guard: an Outcome is terminal, so nothing may follow it.
        let terminal = try makeTestSession(
            vgl: """
                vgraph dt: DecisionTree "Demo" {
                  node o: Outcome "Done";
                }
                """)
        #expect(throws: VError.self) { try terminal.addSuccessor(from: "o", using: EdgeType.Id(string: "anything")) }
        #expect(
            EditorCore.menu(for: "o", in: terminal)
                .first { $0.id == .addSuccessor }?.enabled == false)

        #expect(try s.exportVGL() == before)
    }

    /// What `VAvailability` bought. An Outcome is terminal, so the notation
    /// offers nothing to lead to — which is exactly where "Other type…" is
    /// wanted. ⌥ now reaches it. Before, "nothing to offer" and "the notation
    /// forbids it, unless you insist" were the same `false`, so the break was
    /// unreachable on the one node type that needed it most.
    @Test func permittingTheBreakReachesOtherTypeOnATerminalNode() throws {
        let terminal = try makeTestSession(
            vgl: """
                vgraph dt: DecisionTree "Demo" {
                  node o: Outcome "Done";
                }
                """)

        #expect(
            EditorCore.menu(for: "o", in: terminal, notationBreak: .permitted)
                .first { $0.id == .addSuccessor }?.enabled == true)

        // Only the break itself — the notation has no candidate to add.
        #expect(EditorCore.relatedOptions(from: "o", outgoing: true, in: terminal).map(\.isBreak) == [true])
    }
}
