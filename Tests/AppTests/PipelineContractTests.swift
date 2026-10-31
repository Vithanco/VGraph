////  The pipeline as a declared list of steps rather than opaque closures. Before
////  this, only `sizingSteps` was a `[TransformStep]`, so `orderProblems` could see
////  five of the nine steps and the ledger was silently incomplete: the notation
////  phase and layout recorded nothing at all.
////

import Testing
import VGLanguage

@testable import App
@testable import VGraph

@Suite("Pipeline contract")
struct PipelineContractTests {

    /// A layout engine that does nothing: these tests are about the contract around
    /// layout, not the engine. Computed, since a closure is not `Sendable`.
    private static var noLayout: GraphTransform { { $0 } }

    private func parsed(notation: String) throws -> VGraph {
        try makeTestApp().parseGraph(
            """
            vgraph demo: \(notation) "Demo" {
                node a: \(notation == "ConceptMap" ? "Concept" : "Issue") "A";
            }
            """)
    }

    @Test func wholePipelineIsInValidPrerequisiteOrder() {
        let steps = DisplayPipeline.fullSteps(layout: Self.noLayout)
        #expect(TransformStep.orderProblems(in: steps).isEmpty)
    }

    /// `orderProblems` accepts a duplicated id silently, so uniqueness is its own check.
    @Test func everyPipelineStepIdIsUnique() {
        let ids = DisplayPipeline.fullSteps(layout: Self.noLayout).map { $0.id }
        #expect(Set(ids).count == ids.count)
    }

    /// The test that would have caught the gap: after a full run the ledger must
    /// account for every declared step, not a subset. IBIS contributes no notation
    /// step of its own, so the match is exact.
    @Test func theLedgerAccountsForEveryStep() throws {
        let steps = DisplayPipeline.fullSteps(layout: Self.noLayout)
        let run = try TransformStep.pipeline(steps)(try parsed(notation: "IBIS"))

        #expect(run.completedSteps == Set(steps.map { $0.id }))
    }

    /// A notation's own step records itself *in addition* to the phase, so the ledger
    /// is a tree, not a flat list — which is why no step may require `.mergeRelations`.
    @Test func aNotationStepRecordsItselfBesideThePhase() throws {
        let run = try Notations.notationTransformsStep(try parsed(notation: "ConceptMap"))

        #expect(run.completedSteps.contains(.notationTransforms))
        #expect(run.completedSteps.contains(.mergeRelations))
    }

    @Test func aNotationWithoutAStepStillRecordsThePhase() throws {
        let run = try Notations.notationTransformsStep(try parsed(notation: "IBIS"))

        #expect(run.completedSteps == [.notationTransforms])
    }

    /// Layout consumes final node dimensions. Nothing enforced that before: the engine
    /// was appended to the pipeline as an opaque closure.
    @Test func layoutRefusesToRunBeforeSizing() throws {
        let step = DisplayPipeline.layoutStep(Self.noLayout)

        #expect(throws: VError.self) {
            try step(try parsed(notation: "IBIS"))
        }
    }

    @Test func layoutRecordsItselfOnceSizingHasRun() throws {
        let ready = try parsed(notation: "IBIS").marking(DisplayPipeline.sizingStepIds)

        let run = try DisplayPipeline.layoutStep(Self.noLayout)(ready)

        #expect(run.completedSteps.contains(.layoutGraph))
    }

    /// Folding must precede sizing, but as ordering rather than a prerequisite: the
    /// sizing steps work fine on an unfolded graph, so a `requires:` edge would be
    /// the wrong mechanism (and would make every hand-built test graph throw).
    @Test func foldingPrecedesEverySizingStep() {
        let ids = DisplayPipeline.preLayoutSteps.map { $0.id }
        let fold = ids.firstIndex(of: .foldGroups)
        #expect(fold != nil)

        for sizing in DisplayPipeline.sizingStepIds {
            #expect(ids.firstIndex(of: sizing).map { fold! < $0 } == true)
        }
    }
}
