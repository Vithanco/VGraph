public typealias GraphTransform = (VGraph) throws(VError) -> VGraph

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
        return try body(graph).recordingCompletion(of: id)
    }
}

extension TransformStep.Id {
    /// Declared here rather than in App so any hexagon downstream of layout can ask
    /// whether it ran.
    public static var layoutGraph: Self { "layoutGraph" }
    public static var notationTransforms: Self { "notationTransforms" }
}

extension TransformStep {
    /// The steps run in order, each on the graph the one before produced.
    public static func pipeline(_ steps: [TransformStep]) -> GraphTransform {
        { (graph: VGraph) throws(VError) -> VGraph in
            try steps.folding(graph) { (result, step) throws(VError) in try step(result) }
        }
    }
}

extension VGraph {
    /// Ids of the steps already run on this graph — the evidence a document exporter
    /// checks (`requirePristineForDocumentExport`).
    public var completedSteps: Set<TransformStep.Id> {
        let raw: [String] = (try? get(attribute: Attributes.Group.completedSteps)) ?? []
        return Set(raw.map { TransformStep.Id(rawValue: $0) })
    }

    public func recordingCompletion(of step: TransformStep.Id) throws(VError) -> VGraph {
        var ids = completedSteps
        ids.insert(step)
        return try setting(graphAttribute: Attributes.Group.completedSteps.attribute(ids.map { $0.id }.sorted()))
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
