////
////  TransformStepTests.swift
////  VGraph
////
////  The TransformStep contract in isolation, with synthetic steps:
////  check-before (prerequisites), the body, and set-after (completion recording).
////

import Testing

@testable import VGraph

struct TransformStepTests {

    /// A no-op step body — the contract is what we are testing, not the work.
    private func noop(_ id: TransformStep.Id, requires: [TransformStep.Id] = []) -> TransformStep {
        TransformStep(id, requires: requires) { (g: VGraph) throws(VError) in g }
    }

    /// `orderProblems` takes no transitive closure: c requiring b, and b requiring a,
    /// does not make c require a. That is why a step must declare every prerequisite
    /// it needs rather than relying on its predecessors' declarations.
    @Test func prerequisitesAreNotTransitive() {
        let problems = TransformStep.orderProblems(in: [
            noop("b", requires: ["a"]), noop("c", requires: ["b"]), noop("a"),
        ])

        // Only b's missing 'a' is reported — c is satisfied by b appearing earlier,
        // even though a (which b needs) runs last.
        #expect(problems.count == 1)
        #expect(problems[0].contains("b"))
    }

    // MARK: - set-after

    @Test func runningAStepRecordsItsCompletion() throws {
        let graph = try VGraph().defineStandardAttributes()
        #expect(!graph.completedSteps.contains("a"))

        let result = try noop("a")(graph)

        #expect(result.completedSteps.contains("a"))
    }

    @Test func recordingCompletionIsIdempotent() throws {
        let graph = try VGraph().defineStandardAttributes()
        let once = try graph.recordCompletion(of: "a")
        let twice = try once.recordCompletion(of: "a")
        #expect(twice.completedSteps == ["a"])
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

    // MARK: - static order validation

    @Test func orderProblemsAcceptsValidOrder() {
        let problems = TransformStep.orderProblems(in: [noop("a"), noop("b", requires: ["a"])])
        #expect(problems.isEmpty)
    }

    @Test func orderProblemsRejectsPrerequisiteThatRunsLater() {
        let problems = TransformStep.orderProblems(in: [noop("b", requires: ["a"]), noop("a")])
        #expect(problems.count == 1)
    }
}
