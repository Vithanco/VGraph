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

    /// `identity` does no work, so it gets no ledger entry: a recorded `.identity`
    /// would be a completion another step could depend on, and under the document
    /// export rule it would also bar `transform: identity` graphs from being saved.
    @Test func identityResolvesToNoStep() throws {
        #expect(try TransformRegistry.resolveStep(name: "identity") == nil)
    }

    /// Declaring `static var step` on a notation is the whole job — dispatch is the
    /// registry entry, not a hand-edited switch that a new notation would have to
    /// remember to extend.
    @Test func aNotationsDeclaredStepIsDispatchedByName() {
        #expect(Notations.notationStep(for: "ConceptMap")?.id == .mergeRelations)
        #expect(Notations.notationStep(for: "IBIS") == nil)
        #expect(Notations.notationStep(for: "NoSuchNotation") == nil)
    }

    @Test func unknownNameThrows() {
        #expect(throws: VError.self) {
            try TransformRegistry.resolveStep(name: "noSuchTransform")
        }
    }

    /// A `vnotation` block's `transform:` names replace the compiled notation's own
    /// step rather than adding to it, so a dynamic notation can opt out of a base
    /// notation's transform.
    @Test func declaredTransformNamesReplaceTheNotationsOwnStep() throws {
        var graph = try VGraph().defineStandardAttributes()
        graph = graph.using(notation: "ConceptMap")
        #expect(try Notations.resolveSteps(for: graph).map { $0.id } == [.mergeRelations])

        graph = graph.declaring(transforms: ["identity"])
        #expect(try Notations.resolveSteps(for: graph).isEmpty)
    }
}
