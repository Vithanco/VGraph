//
//  RubberBandTest.swift
//  VGraph
//
//  What a [[Rubber band]] catches (ADR-0018, ADR-0003).
//
//  The *measuring* stays in the browser and is not tested here. A band catches
//  what the user sees, and what is drawn is the renderer's business, not the
//  domain's: a folded group's proxy node carries two shadow layers at +5 and
//  +10 px that `NodeStyleLayout+Dimensions` deliberately sizes as
//  `VSize.zero`, so its drawn box is 10px larger than its laid-out one in both
//  axes. Asking the domain what a band encloses would answer a different
//  question from the one the user asked — and would do it wrongly for exactly
//  the elements this rule singles out.
//
//  So bounds arrive already measured, and what is decided here is the two
//  rules: which elements may be caught at all, and what "enclosed" means.
//

import EditorCore
import Testing
import VGLanguage
import VGraph

@testable import App

struct RubberBandTest {
    private func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> VRect {
        VRect(origin: VPoint(x: x, y: y), size: VSize(width: w, height: h))
    }

    private func conceptMap() throws -> TestSession {
        try makeTestSession(
            vgl: """
                vgraph demo: ConceptMap "Demo" {
                  node a: Concept "A";
                  node b: Concept "B";
                }
                """)
    }

    /// *Contained*, not *touched*. Nothing in a diagram is impossible to
    /// enclose, so forgiveness would only buy accidental selection (ADR-0018).
    @Test("A band takes what it wholly encloses and leaves what it only clips")
    func containedNotTouched() throws {
        let session = try conceptMap()
        let band = rect(0, 0, 100, 100)

        let caught = EditorCore.bandCatch(
            band,
            over: [
                BandCandidate(id: "a", bounds: rect(10, 10, 50, 50)),
                BandCandidate(id: "b", bounds: rect(80, 80, 50, 50)),
            ],
            in: session)

        #expect(caught == ["a"])
    }

    /// Only what is drawn as a single box: a node, or a folded group — which is
    /// one thing at this zoom, [[Fold state]] deciding as ADR-0003 says. An open
    /// boundary's interior belongs to the band and has to stay there, or
    /// band-selecting inside one becomes impossible; the boundary itself arrives
    /// by promotion instead (ADR-0018). An edge is never selectable at all
    /// (ADR-0017).
    @Test("Only a node or a folded group is caught")
    func onlyWhatIsDrawnAsOneBoxIsCaught() throws {
        let session = try makeTestSession(
            vgl: """
                vgraph demo: ConceptMap "Demo" {
                  node a: Concept "A";
                  group open "Open" { node b: Concept "B"; }
                  group shut "Shut" { node c: Concept "C"; }
                  edge a -> b;
                }
                """)
        try session.toggleFolding(of: "shut")
        let edgeId = session.origin.edges.first!.id.id

        // A band big enough that containment is never the reason anything is
        // dropped — the filter is what is under test.
        let caught = EditorCore.bandCatch(
            rect(0, 0, 1000, 1000),
            over: ["a", "open", "shut", edgeId].map {
                BandCandidate(id: $0, bounds: rect(10, 10, 20, 20))
            },
            in: session)

        #expect(caught == ["a", "shut"])
    }
}
