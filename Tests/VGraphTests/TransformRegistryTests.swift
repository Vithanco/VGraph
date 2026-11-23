////
////  TransformRegistryTests.swift
////  VGraph
////
////  `vnotation` blocks name their transforms as strings. The registry resolved those
////  to bare closures, discarding the `TransformStep` it already held — so a
////  vnotation-declared transform ran without ever recording itself.
////

import Testing

@testable import VGraph

@Suite("Transform registry")
struct TransformRegistryTests {

    @Test func mergeRelationsResolvesToItsStep() throws {
        #expect(try TransformRegistry.resolveStep(name: "mergeRelations")?.id == .mergeRelations)
    }

    @Test func unknownNameThrows() {
        #expect(throws: VError.parsingError("Unknown transform 'noSuchTransform'. Available: mergeRelations, identity")) {
            try TransformRegistry.resolveStep(name: "noSuchTransform")
        }
    }

    /// A `vnotation` block's `transform:` names replace the compiled notation's own
    /// step rather than adding to it, so a dynamic notation can opt out of a base
    /// notation's transform.
    /// `identity` resolves to no step: a recorded `.identity` would be a completion
    /// another step could depend on, and it would bar `transform: identity` graphs
    /// from being saved.
    @Test func declaredTransformNamesReplaceTheNotationsOwnStep() throws {
        var graph = VGraph()
        graph = graph.using(notation: "ConceptMap")
        #expect(try Notations.resolveSteps(for: graph).map { $0.id } == [.mergeRelations])

        graph = graph.declaring(transforms: ["identity"])
        #expect(try Notations.resolveSteps(for: graph).isEmpty)
    }
}
