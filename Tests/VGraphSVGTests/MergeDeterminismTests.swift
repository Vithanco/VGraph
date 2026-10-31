// ConceptMap merges two Relation nodes sharing a label and a target. Which of
// the pair survived used to follow `Set` order, so `vgraph-architecture.vgl`
// rendered one of two SVGs at roughly 50/50, the same node carrying a different
// id each time.

import TestSupport
import Testing
import VGraph

@testable import App

@Suite("Two relations that merge")
struct MergeDeterminismTests {

    private static let source = """
        vgraph m: ConceptMap "Merge" {
            node ve: Concept "VGLExporter"
            node de: Concept "DotExporter"
            node vg: Concept "VGraph"

            node r24: Relation "serializes"
            edge ve -> r24
            edge r24 -> vg

            node r25: Relation "serializes"
            edge de -> r25
            edge r25 -> vg
        }
        """

    private func render(_ vgl: String) throws -> String {
        let app = VGraphTestApp()
        return try app.renderGraph(graph: try app.parseGraph(vgl), sourceVGL: vgl).svg
    }

    @Test("The one declared first is the one that survives")
    func theEarlierDeclarationSurvives() throws {
        let svg = try render(Self.source)

        #expect(svg.contains("id=\"node-r24\""))
        #expect(!svg.contains("id=\"node-r25\""))
    }

    /// The pair written the other way round: the survivor tracks the document,
    /// not the ids — which is what a hash order could never do.
    func swapped() -> String {
        Self.source
            .replacingOccurrences(of: "r24", with: "TMP")
            .replacingOccurrences(of: "r25", with: "r24")
            .replacingOccurrences(of: "TMP", with: "r25")
    }

    @Test("Swapping which is declared first swaps the survivor")
    func swappingTheOrderSwapsTheSurvivor() throws {
        let svg = try render(swapped())

        #expect(svg.contains("id=\"node-r25\""))
        #expect(!svg.contains("id=\"node-r24\""))
    }

    @Test("Repeated renders are byte-identical")
    func repeatedRendersAgree() throws {
        let first = try render(Self.source)
        for _ in 0..<4 {
            #expect(try render(Self.source) == first)
        }
    }

    @Test("The merge really happened")
    func theMergeStillHappens() throws {
        let svg = try render(Self.source)

        var relationNodes = 0
        var searched = Substring(svg)
        while let found = searched.range(of: "class=\"vgraph-node\"") {
            relationNodes += 1
            searched = searched[found.upperBound...]
        }
        #expect(relationNodes == 4, "three concepts and one merged relation, not five nodes")
    }
}
