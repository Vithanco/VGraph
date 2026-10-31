////  VGL is the document format: it is serialised from the OriginGraph, never from
////  pipeline output. `completedSteps` is exactly the evidence that the pipeline ran,
////  so a non-empty ledger is a hard stop at the document exporter — the sink, where
////  every caller passes through, rather than one guarded call site.
////

import Testing

@testable import VGLanguage
@testable import VGraph

@Suite("VGL export requires a pristine graph")
struct VGLExportRequiresPristineGraphTests {

    private let source = """
        vgraph demo: ConceptMap "Demo" {
            node a: Concept "A";
        }
        """

    private func parsed() throws -> VGraph {
        try VGraphParser(logger: NoOpLogger()).parse(source: source)
    }

    @Test func aParsedGraphExports() throws {
        let graph = try parsed()
        #expect(graph.completedSteps.isEmpty)

        #expect(try VGLExporter().export(graph: graph).contains("node a"))
    }

    @Test func oneRecordedStepBlocksExport() throws {
        let touched = try parsed().recordCompletion(of: .foldGroups)

        #expect(throws: VError.documentExportOfTransformedGraph(steps: ["foldGroups"])) {
            try VGLExporter().export(graph: touched)
        }
    }

    /// The ledger must not be forgeable from VGL text: a file that authored one would
    /// parse into a graph that can never be saved again. `completedSteps` is a display
    /// attribute, and the parser refuses every one of those.
    @Test func theLedgerCannotBeAuthoredInVGL() {
        #expect(throws: VError.self) {
            try VGraphParser(logger: NoOpLogger()).parse(
                source: """
                    vgraph demo: ConceptMap "Demo" {
                        completedsteps: "[foldGroups]";
                        node a: Concept "A";
                    }
                    """)
        }
    }

    /// The error names every step that ran, so the message points at the pipeline
    /// that produced the graph rather than just the first thing it noticed.
    @Test func theErrorListsEveryCompletedStep() throws {
        let touched = try parsed().marking([.boundaryChrome, .foldGroups])

        #expect(throws: VError.documentExportOfTransformedGraph(steps: ["boundaryChrome", "foldGroups"])) {
            try VGLExporter().export(graph: touched)
        }
    }
}
