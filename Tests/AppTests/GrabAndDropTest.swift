//
//  GrabAndDropTest.swift
//  VGraph
//
//  What a press grabs, and what releasing it over something means. One press
//  carries three commands — connect (ADR-0012), move (ADR-0019) and reattach
//  (ADR-0021) — told apart by what was grabbed and where it landed.
//
//  The hit tests stay in the browser: `closest` walks up from the exact shape
//  under the pointer and gets z-order right. What arrives here is what it found.
//

import EditorCore
import Testing
import VGLanguage
import VGraph

@testable import App

struct GrabAndDropTest {
    private func session() throws -> TestSession {
        try makeTestSession(
            vgl: """
                vgraph demo: ConceptMap "Demo" {
                  group g1 "Cluster" {
                    node a: Concept "A";
                  }
                  node r: Relation "leads to";
                  edge a -> r;
                }
                """)
    }

    private func edgeId(_ s: TestSession) throws -> String {
        try #require(s.origin.edges.first).id.id
    }

    // MARK: - Grab

    /// The handle sits inside its edge's `<g>`, so the element walk finds the
    /// edge too — and an edge alone would start a band.
    @Test func anEdgeEndHandleIsGrabbedAsTheEnd() throws {
        let s = try session()
        let edge = try edgeId(s)
        #expect(
            EditorCore.grab(edgeEnd: (edge, .to), groupLabel: "", element: edge, in: s)
                == .edgeEnd(edge: edge, end: .to))
    }

    @Test func aNodeIsGrabbed() throws {
        #expect(EditorCore.grab(edgeEnd: nil, groupLabel: "", element: "a", in: try session()) == .element("a"))
    }

    /// By its label only: the interior belongs to the [[Rubber band]].
    @Test func aGroupIsGrabbedByItsLabel() throws {
        let s = try session()
        #expect(EditorCore.grab(edgeEnd: nil, groupLabel: "g1", element: "g1", in: s) == .element("g1"))
        #expect(EditorCore.grab(edgeEnd: nil, groupLabel: "", element: "g1", in: s) == nil)
    }

    /// `nil` is the band's: blank canvas, a group's interior, an edge.
    @Test func blankCanvasAndEdgesAreNotGrabbed() throws {
        let s = try session()
        #expect(EditorCore.grab(edgeEnd: nil, groupLabel: "", element: "", in: s) == nil)
        #expect(EditorCore.grab(edgeEnd: nil, groupLabel: "", element: try edgeId(s), in: s) == nil)
    }

    // MARK: - Drop

    /// The drop target picks the command: over a group (or blank canvas, which
    /// arrives as the [[Root group]]) the drag is a move.
    @Test func overAGroupItIsAMove() throws {
        #expect(
            EditorCore.drop(.element("r"), on: "g1", moveDestination: "g1", in: try session())
                == .move(source: "r", into: "g1"))
    }

    @Test func overAnotherNodeItIsAConnect() throws {
        #expect(
            EditorCore.drop(.element("a"), on: "r", moveDestination: "", in: try session())
                == .connect(from: "a", to: "r"))
    }

    @Test func backOnItselfOrOverNothingItIsNothing() throws {
        let s = try session()
        #expect(EditorCore.drop(.element("a"), on: "a", moveDestination: "", in: s) == nil)
        #expect(EditorCore.drop(.element("a"), on: "", moveDestination: "", in: s) == nil)
    }

    /// An edge end cannot join a group — its edge's group is derived
    /// (ADR-0017) — so only a node takes it, and a move is never asked.
    @Test func anEndLandsOnANodeOrNowhere() throws {
        let s = try session()
        let edge = try edgeId(s)
        let end = EditorCore.Grab.edgeEnd(edge: edge, end: .from)
        #expect(
            EditorCore.drop(end, on: "r", moveDestination: "g1", in: s)
                == .reattach(edge: edge, end: .from, to: "r"))
        #expect(EditorCore.drop(end, on: "g1", moveDestination: "g1", in: s) == nil)
        #expect(EditorCore.drop(end, on: "", moveDestination: s.rootGroupId(), in: s) == nil)
    }
}
