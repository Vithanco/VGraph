//
//  SplitEdgeTest.swift
//  VGraph
//
//  The Split command: insert a node between an edge's endpoints, staying inside
//  the notation unless the user allows a break.
//

import EditorCore
import Testing
import VGLanguage
import VGraph

@testable import App

struct SplitEdgeTest {
    private func goalTree(edgeLabel: String = "") throws -> TestSession {
        let label = edgeLabel.isEmpty ? "" : " \"\(edgeLabel)\""
        return try makeTestSession(
            vgl: """
                vgraph gt: GoalTree "Demo" {
                  node g: Goal "Win";
                  node c: CriticalSuccessFactor "Ship";
                  node n: NecessaryCondition "Test";
                  edge c -> g;
                  edge n -> c\(label);
                }
                """)
    }

    private func edgeId(_ s: TestSession, from: String, to: String) -> String {
        s.origin.edges.first { $0.from.id == from && $0.to.id == to }!.id.id
    }

    /// A Goal Tree allows exactly one thing between a NecessaryCondition and a
    /// CriticalSuccessFactor — another NecessaryCondition — so there is nothing
    /// to choose and the command applies straight away.
    ///
    /// `_2`, not `_1`: ids start counting from how many of that type exist, and
    /// `n` is already a NecessaryCondition. See `NewNodeIdTests`.
    @Test func theOnlyWayToSplitNeedsNoQuestion() throws {
        let s = try goalTree()
        let target = edgeId(s, from: "n", to: "c")

        #expect(
            try s.split(target, with: s.splitCandidates(for: target).first!)
                == "necessarycondition_2")

        let exported = try s.exportVGL()
        #expect(exported.contains("node necessarycondition_2: NecessaryCondition \"Change Me\""))
        #expect(exported.contains("edge n -> necessarycondition_2"))
        #expect(exported.contains("edge necessarycondition_2 -> c"))
        #expect(!exported.contains("edge n -> c"))
        try s.replaceDocument(vgl: exported)
    }

    /// One relationship becomes two. The label and the comment the user wrote
    /// describe what leaves the source, so they ride along on the first segment
    /// rather than disappearing with the edge that carried them.
    @Test func theFirstSegmentInheritsTheOldEdgesAttributes() throws {
        let s = try goalTree(edgeLabel: "needs")
        let target = edgeId(s, from: "n", to: "c")

        #expect(
            try s.split(target, with: s.splitCandidates(for: target).first!)
                == "necessarycondition_2")

        let exported = try s.exportVGL()
        #expect(exported.contains("edge n -> necessarycondition_2 \"needs\""))
        #expect(!exported.contains("edge necessarycondition_2 -> c \"needs\""))
    }

    /// A Current Reality Tree lets several effect types sit between two
    /// undesirable effects, so the command asks which one first.
    @Test func offersEveryTypeTheNotationAllowsBetweenTheEndpoints() throws {
        let s = try makeTestSession(
            vgl: """
                vgraph crt: CRT "Demo" {
                  node u1: UndesirableEffect "Sales are falling";
                  node u2: UndesirableEffect "Margins shrink";
                  edge u1 -> u2;
                }
                """)
        let target = s.origin.edges.first!.id.id

        let options = EditorCore.splitOptions(for: target, notationBreak: .forbidden, in: s)
        let titles = Set(options.map { $0.title })
        #expect(titles.contains("IntermediateEffect"))
        #expect(titles.contains("AndJunctor"))
        #expect(!options.contains { $0.isBreak })

        let picked = s.splitCandidates(for: target).first { $0.title == "IntermediateEffect" }!
        #expect(try s.split(target, with: picked) == "intermediateeffect_1")

        let exported = try s.exportVGL()
        #expect(exported.contains("edge u1 -> intermediateeffect_1"))
        #expect(exported.contains("edge intermediateeffect_1 -> u2"))
    }

    /// When two edge types could carry the same segment, the node type alone does
    /// not name the option — a Causal Loop Diagram has one node type and two
    /// relationships, so every combination has to be spelled out.
    ///
    /// `stock_3` because two Stocks already exist, hand-named or not.
    @Test func namesTheRelationshipsWhenTheNodeTypeIsNotEnough() throws {
        let s = try makeTestSession(
            vgl: """
                vgraph cld: CLD "Demo" {
                  node s1: Stock "Price";
                  node s2: Stock "Demand";
                  edge s1 -> s2: same;
                }
                """)
        let target = s.origin.edges.first!.id.id

        let options = EditorCore.splitOptions(for: target, notationBreak: .forbidden, in: s)
        #expect(options.count == 4)
        #expect(options.contains { $0.title == "Stock (same → opposite)" })

        let picked = s.splitCandidates(for: target).first { $0.title == "Stock (same → opposite)" }!
        #expect(try s.split(target, with: picked) == "stock_3")

        let exported = try s.exportVGL()
        #expect(exported.contains("edge s1 -> stock_3: same"))
        #expect(exported.contains("edge stock_3 -> s2: opposite"))
    }

    /// Nothing may sit between a Concept and a Relation, so the command greys out
    /// until the user allows the break — which then opens the full node-type list
    /// and wires up whatever the notation lacks as an unknown (red) edge type.
    @Test func allowingTheBreakOpensTheFullNodeTypeList() throws {
        let s = try makeTestSession(
            vgl: """
                vgraph demo: ConceptMap "Demo" {
                  node a: Concept "A";
                  node r: Relation "leads to";
                  edge a -> r;
                }
                """)
        let target = s.origin.edges.first!.id.id

        let greyed = EditorCore.menu(for: target, in: s).first { $0.id == .split }
        #expect(greyed?.enabled == false)
        #expect(greyed?.title == "Split (breaks notation)")
        #expect(EditorCore.splitOptions(for: target, notationBreak: .forbidden, in: s).isEmpty)

        // ⌥ turns it into a question whose only entry is the break itself.
        let options = EditorCore.splitOptions(for: target, notationBreak: .permitted, in: s)
        #expect(options.map(\.isBreak) == [true])

        // Behind it, the full type list.
        #expect(EditorCore.breakTypeOptions(in: s).contains { $0.id == "Concept" })

        #expect(try s.split(target, ofType: NodeType(string: "Concept")) == "concept_2")

        let exported = try s.exportVGL()
        #expect(exported.contains("edge a -> concept_2"))
        #expect(exported.contains("edge concept_2 -> r"))
        #expect(!GenericQualityChecks.unknownEdgeTypes(graph: s.origin).isEmpty)
    }

    /// The inserted node takes the edge's place, group included.
    @Test func theNewNodeJoinsTheEdgesGroup() throws {
        let s = try makeTestSession(
            vgl: """
                vgraph gt: GoalTree "Demo" {
                  group g1 "Cluster" {
                    node c: CriticalSuccessFactor "Ship";
                    node n: NecessaryCondition "Test";
                    edge n -> c;
                  }
                }
                """)
        let target = edgeId(s, from: "n", to: "c")

        #expect(
            try s.split(target, with: s.splitCandidates(for: target).first!)
                == "necessarycondition_2")

        // Emitted inside the group's braces, not after them.
        let exported = try s.exportVGL()
        let inside = exported.range(of: "node necessarycondition_2")
        let groupEnd = exported.range(of: "}")
        #expect(inside != nil && groupEnd != nil)
        #expect(inside!.lowerBound < groupEnd!.lowerBound)
    }

    /// A type with no user text gets no inline editor, exactly as when a
    /// successor is added.
    @Test func aTypeThatDisplaysNoLabelGetsNoInlineEditor() throws {
        let s = try makeTestSession(
            vgl: """
                vgraph crt: CRT "Demo" {
                  node u1: UndesirableEffect "Sales are falling";
                  node u2: UndesirableEffect "Margins shrink";
                  edge u1 -> u2;
                }
                """)
        let target = s.origin.edges.first!.id.id

        let junctor = s.splitCandidates(for: target).first { $0.title == "AndJunctor" }!

        // An icon-only node type has nothing to type, so nothing to open.
        #expect(try s.split(target, with: junctor) == nil)
        #expect(try s.exportVGL().contains("node andjunctor_1: AndJunctor \"Change Me\""))
    }
}
