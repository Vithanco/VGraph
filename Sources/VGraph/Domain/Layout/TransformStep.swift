////
////  TransformStep.swift
////  VGraph
////
////  A named GraphTransform with prerequisites and self-recording.
////

/// A named `GraphTransform` with prerequisites, which records itself as completed
/// once its body succeeds.
///
/// `body` is private and reachable only through `callAsFunction`, so the
/// check→body→record contract cannot be bypassed or half-applied.
public struct TransformStep {
    public typealias Id = Identifier<TransformStep>

    public let id: Id
    public let prerequisites: [Id]
    private let body: GraphTransform

    public init(_ id: Id, requires prerequisites: [Id] = [], _ body: @escaping GraphTransform) {
        self.id = id
        self.prerequisites = prerequisites
        self.body = body
    }

    public func callAsFunction(_ graph: VGraph) throws(VError) -> VGraph {
        try graph.checkPrerequisites(of: self)
        return try body(graph).recordCompletion(of: id)
    }

    public var asTransform: GraphTransform {
        { (graph: VGraph) throws(VError) -> VGraph in try self(graph) }
    }
}

extension TransformStep {
    /// Deliberately not a `TransformPipeline.compose` overload: that would make
    /// empty-literal call sites ambiguous.
    public static func pipeline(_ steps: [TransformStep]) -> GraphTransform {
        TransformPipeline.compose(steps.map { $0.asTransform })
    }

    /// Catches a mis-ordered pipeline without running it: one problem per step whose
    /// prerequisite runs later (empty == valid).
    public static func orderProblems(in steps: [TransformStep]) -> [String] {
        var satisfied: Set<Id> = []
        var problems: [String] = []
        for step in steps {
            for prerequisite in step.prerequisites where !satisfied.contains(prerequisite) {
                problems.append("\(step.id) requires \(prerequisite), which does not run earlier")
            }
            satisfied.insert(step.id)
        }
        return problems
    }
}

extension VGraph {
    /// Ids of the steps already run on this graph — the evidence a document exporter
    /// checks (`requirePristineForDocumentExport`).
    public var completedSteps: Set<TransformStep.Id> {
        let raw: [String] = (try? get(attribute: Attributes.Group.completedSteps)) ?? []
        return Set(raw.map { TransformStep.Id(rawValue: $0) })
    }

    public func recordCompletion(of step: TransformStep.Id) throws(VError) -> VGraph {
        var ids = completedSteps
        ids.insert(step)
        return try set(graphAttribute: Attributes.Group.completedSteps.attribute(ids.map { $0.id }.sorted()))
    }

    /// Records several completed steps at once. Primarily for tests and setup code
    /// that needs to satisfy a step's prerequisites without running its predecessors
    /// (e.g. `graph.marking(calculateNodeDimensions.prerequisites)`).
    public func marking(_ steps: [TransformStep.Id]) throws(VError) -> VGraph {
        var result = self
        for step in steps {
            result = try result.recordCompletion(of: step)
        }
        return result
    }

    /// Gate for *document* exporters: pipeline output must never be written back into
    /// the user's file. Render targets (DOT, SVG) are downstream of the pipeline and
    /// deliberately do not call this.
    public func requirePristineForDocumentExport() throws(VError) {
        let steps = completedSteps
        guard steps.isEmpty else {
            throw VError.documentExportOfTransformedGraph(steps: steps.map { $0.id }.sorted())
        }
    }

    public func checkPrerequisites(of step: TransformStep) throws(VError) {
        let done = completedSteps
        let missing = step.prerequisites.filter { !done.contains($0) }
        guard missing.isEmpty else {
            throw VError.pipelineContractViolated(step: step.id.id, missing: missing.map { $0.id })
        }
    }
}
