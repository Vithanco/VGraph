////
////  TransformStepTests.swift
////  VGraph
////
////  The TransformStep contract in isolation, with synthetic steps:
////  check-before (prerequisites), the body, and set-after (completion recording).
////

import TestSupport
import Testing

@testable import VGraph

struct TransformStepTests {

    /// A no-op step body — the contract is what we are testing, not the work.
    private func noop(_ id: TransformStep.Id, requires: [TransformStep.Id] = []) -> TransformStep {
        TransformStep(id, requires: requires) { (g: VGraph) throws(VError) in g }
    }

    // MARK: - set-after

    @Test func runningAStepRecordsItsCompletion() throws {
        let graph = try VGraph().defineStandardAttributes()
        #expect(!graph.completedSteps.contains("a"))

        let result = try noop("a")(graph)

        #expect(result.completedSteps.contains("a"))
    }

    @Test func recordingCompletionAccumulatesOnce() throws {
        let graph = try VGraph().defineStandardAttributes()
        let recorded = try graph.recordCompletion(of: "a").recordCompletion(of: "b").recordCompletion(of: "a")
        #expect(recorded.completedSteps == ["a", "b"])
    }

    // MARK: - check-before

    @Test func missingPrerequisiteThrowsNamingTheGap() throws {
        let graph = try VGraph().defineStandardAttributes()
        #expect(throws: VError.pipelineContractViolated(step: "b", missing: ["a"])) {
            try noop("b", requires: ["a"])(graph)
        }
    }

    @Test func satisfiedPrerequisitePasses() throws {
        let graph = try VGraph().defineStandardAttributes().marking(["a"])
        let result = try noop("b", requires: ["a"])(graph)
        #expect(result.completedSteps.contains("b"))
    }
}
