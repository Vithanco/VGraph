import TestSupport
import Testing

@testable import VGraph

@Suite
struct MergeRelationsTests {

    // MARK: - Test Fixtures

    typealias CM = Notations.ConceptMap

    private func createConceptMapGraph() throws(VError) -> VGraph {
        var graph = try VGraph()
            .defineStandardAttributes()
        graph = try CM.addNotation(addTo: graph)
        graph = graph.using(notation: "ConceptMap")
        return graph
    }

    private func addConcept(_ id: String, label: String, to graph: VGraph) throws(VError) -> VGraph {
        let node = Node(string: id)
        var result = try graph.add(node: node, type: CM.NodeTypes.concept)
        result = try result.set(node: node, attribute: Attributes.Node.label.attribute(label))
        return result
    }

    private func addEmphasizedConcept(_ id: String, label: String, to graph: VGraph) throws(VError) -> VGraph {
        let node = Node(string: id)
        var result = try graph.add(node: node, type: CM.NodeTypes.emphasizedConcept)
        result = try result.set(node: node, attribute: Attributes.Node.label.attribute(label))
        return result
    }

    private func addRelation(_ id: String, label: String, to graph: VGraph) throws(VError) -> VGraph {
        let node = Node(string: id)
        var result = try graph.add(node: node, type: CM.NodeTypes.relation)
        result = try result.set(node: node, attribute: Attributes.Node.label.attribute(label))
        return result
    }

    private func addEdgeConceptToRelation(id: String, from: String, to: String, in graph: VGraph) throws(VError)
        -> VGraph
    {
        let edge = Edge(string: id, from: from, to: to)
        return try graph.add(edge: edge, edgeType: CM.EdgeTypes.conceptToRelation)
    }

    private func addEdgeRelationToConcept(id: String, from: String, to: String, in graph: VGraph) throws(VError)
        -> VGraph
    {
        let edge = Edge(string: id, from: from, to: to)
        return try graph.add(edge: edge, edgeType: CM.EdgeTypes.relationToConcept)
    }

    private func addEdgeEmphasizedConceptToRelation(id: String, from: String, to: String, in graph: VGraph)
        throws(VError) -> VGraph
    {
        let edge = Edge(string: id, from: from, to: to)
        return try graph.add(edge: edge, edgeType: CM.EdgeTypes.emphasizedConceptToRelation)
    }

    private func addEdgeRelationToEmphasizedConcept(id: String, from: String, to: String, in graph: VGraph)
        throws(VError) -> VGraph
    {
        let edge = Edge(string: id, from: from, to: to)
        return try graph.add(edge: edge, edgeType: CM.EdgeTypes.relationToEmphasizedConcept)
    }

    // MARK: - findMergeableRelations — Identification

    @Test
    func find_noRelationNodes_returnsEmpty() throws(VError) {
        var graph = try createConceptMapGraph()
        graph = try addConcept("c1", label: "Dog", to: graph)

        let groups = findMergeableRelations(in: graph)
        #expect(groups.isEmpty)
    }

    @Test
    func find_singleRelation_returnsEmpty() throws(VError) {
        var graph = try createConceptMapGraph()
        graph = try addConcept("c1", label: "Dog", to: graph)
        graph = try addRelation("r1", label: "is a", to: graph)
        graph = try addConcept("c2", label: "Mammal", to: graph)
        graph = try addEdgeConceptToRelation(id: "e1", from: "c1", to: "r1", in: graph)
        graph = try addEdgeRelationToConcept(id: "e2", from: "r1", to: "c2", in: graph)

        let groups = findMergeableRelations(in: graph)
        #expect(groups.isEmpty)
    }

    @Test
    func find_differentLabels_returnsEmpty() throws(VError) {
        // Dog -[is a]-> Mammal, Cat -[likes]-> Mammal  — different labels, no match
        var graph = try createConceptMapGraph()
        graph = try addConcept("dog", label: "Dog", to: graph)
        graph = try addConcept("cat", label: "Cat", to: graph)
        graph = try addConcept("mammal", label: "Mammal", to: graph)
        graph = try addRelation("r1", label: "is a", to: graph)
        graph = try addRelation("r2", label: "likes", to: graph)
        graph = try addEdgeConceptToRelation(id: "e1", from: "dog", to: "r1", in: graph)
        graph = try addEdgeRelationToConcept(id: "e2", from: "r1", to: "mammal", in: graph)
        graph = try addEdgeConceptToRelation(id: "e3", from: "cat", to: "r2", in: graph)
        graph = try addEdgeRelationToConcept(id: "e4", from: "r2", to: "mammal", in: graph)

        let groups = findMergeableRelations(in: graph)
        #expect(groups.isEmpty)
    }

    @Test
    func find_sameLabelDifferentTargets_returnsEmpty() throws(VError) {
        // Dog -[is a]-> Mammal, Cat -[is a]-> Feline  — same label, different targets
        var graph = try createConceptMapGraph()
        graph = try addConcept("dog", label: "Dog", to: graph)
        graph = try addConcept("cat", label: "Cat", to: graph)
        graph = try addConcept("mammal", label: "Mammal", to: graph)
        graph = try addConcept("feline", label: "Feline", to: graph)
        graph = try addRelation("r1", label: "is a", to: graph)
        graph = try addRelation("r2", label: "is a", to: graph)
        graph = try addEdgeConceptToRelation(id: "e1", from: "dog", to: "r1", in: graph)
        graph = try addEdgeRelationToConcept(id: "e2", from: "r1", to: "mammal", in: graph)
        graph = try addEdgeConceptToRelation(id: "e3", from: "cat", to: "r2", in: graph)
        graph = try addEdgeRelationToConcept(id: "e4", from: "r2", to: "feline", in: graph)

        let groups = findMergeableRelations(in: graph)
        #expect(groups.isEmpty)
    }

    @Test
    func find_partialTargetOverlap_returnsEmpty() throws(VError) {
        // r1 -[has]-> {Weight, Style}, r2 -[has]-> {Weight, Color}
        // Same label, overlapping but NOT identical targets — no merge
        var graph = try createConceptMapGraph()
        graph = try addConcept("font", label: "Font", to: graph)
        graph = try addConcept("font2", label: "Font2", to: graph)
        graph = try addConcept("weight", label: "Weight", to: graph)
        graph = try addConcept("style", label: "Style", to: graph)
        graph = try addConcept("color", label: "Color", to: graph)
        graph = try addRelation("r1", label: "has", to: graph)
        graph = try addRelation("r2", label: "has", to: graph)
        graph = try addEdgeConceptToRelation(id: "e1", from: "font", to: "r1", in: graph)
        graph = try addEdgeRelationToConcept(id: "e2", from: "r1", to: "weight", in: graph)
        graph = try addEdgeRelationToConcept(id: "e3", from: "r1", to: "style", in: graph)
        graph = try addEdgeConceptToRelation(id: "e4", from: "font2", to: "r2", in: graph)
        graph = try addEdgeRelationToConcept(id: "e5", from: "r2", to: "weight", in: graph)
        graph = try addEdgeRelationToConcept(id: "e6", from: "r2", to: "color", in: graph)

        let groups = findMergeableRelations(in: graph)
        #expect(groups.isEmpty)
    }

    @Test
    func find_relationWithNoOutgoingEdges_excluded() throws(VError) {
        // r1 has outgoing edge to mammal, r2 has no outgoing edge — not mergeable
        var graph = try createConceptMapGraph()
        graph = try addConcept("dog", label: "Dog", to: graph)
        graph = try addConcept("mammal", label: "Mammal", to: graph)
        graph = try addRelation("r1", label: "is a", to: graph)
        graph = try addRelation("r2", label: "is a", to: graph)
        graph = try addEdgeConceptToRelation(id: "e1", from: "dog", to: "r1", in: graph)
        graph = try addEdgeRelationToConcept(id: "e2", from: "r1", to: "mammal", in: graph)
        graph = try addEdgeConceptToRelation(id: "e3", from: "dog", to: "r2", in: graph)
        // r2 has NO outgoing edge

        let groups = findMergeableRelations(in: graph)
        #expect(groups.isEmpty)
    }

    @Test
    func find_twoMergeablePair_returnsOneGroup() throws(VError) {
        // Dog -[is a]-> Mammal, Cat -[is a]-> Mammal
        var graph = try createConceptMapGraph()
        graph = try addConcept("dog", label: "Dog", to: graph)
        graph = try addConcept("cat", label: "Cat", to: graph)
        graph = try addConcept("mammal", label: "Mammal", to: graph)
        graph = try addRelation("r1", label: "is a", to: graph)
        graph = try addRelation("r2", label: "is a", to: graph)
        graph = try addEdgeConceptToRelation(id: "e1", from: "dog", to: "r1", in: graph)
        graph = try addEdgeRelationToConcept(id: "e2", from: "r1", to: "mammal", in: graph)
        graph = try addEdgeConceptToRelation(id: "e3", from: "cat", to: "r2", in: graph)
        graph = try addEdgeRelationToConcept(id: "e4", from: "r2", to: "mammal", in: graph)

        let groups = findMergeableRelations(in: graph)
        #expect(groups.count == 1)
        #expect(groups[0].label == "is a")
        #expect(groups[0].nodes.count == 2)
        #expect(groups[0].targets == Set([Node(string: "mammal")]))
    }

    @Test
    func find_threeWayMerge_returnsGroupOfThree() throws(VError) {
        var graph = try createConceptMapGraph()
        graph = try addConcept("dog", label: "Dog", to: graph)
        graph = try addConcept("cat", label: "Cat", to: graph)
        graph = try addConcept("fish", label: "Fish", to: graph)
        graph = try addConcept("animal", label: "Animal", to: graph)
        graph = try addRelation("r1", label: "is a", to: graph)
        graph = try addRelation("r2", label: "is a", to: graph)
        graph = try addRelation("r3", label: "is a", to: graph)
        graph = try addEdgeConceptToRelation(id: "e1", from: "dog", to: "r1", in: graph)
        graph = try addEdgeRelationToConcept(id: "e2", from: "r1", to: "animal", in: graph)
        graph = try addEdgeConceptToRelation(id: "e3", from: "cat", to: "r2", in: graph)
        graph = try addEdgeRelationToConcept(id: "e4", from: "r2", to: "animal", in: graph)
        graph = try addEdgeConceptToRelation(id: "e5", from: "fish", to: "r3", in: graph)
        graph = try addEdgeRelationToConcept(id: "e6", from: "r3", to: "animal", in: graph)

        let groups = findMergeableRelations(in: graph)
        #expect(groups.count == 1)
        #expect(groups[0].nodes.count == 3)
    }

    @Test
    func find_twoIndependentMergeGroups() throws(VError) {
        // Group1: r_isa1, r_isa2 both -[is a]-> Animal
        // Group2: r_has1, r_has2 both -[has]-> Fur
        var graph = try createConceptMapGraph()
        graph = try addConcept("dog", label: "Dog", to: graph)
        graph = try addConcept("cat", label: "Cat", to: graph)
        graph = try addConcept("animal", label: "Animal", to: graph)
        graph = try addConcept("fur", label: "Fur", to: graph)
        graph = try addRelation("r_isa1", label: "is a", to: graph)
        graph = try addRelation("r_isa2", label: "is a", to: graph)
        graph = try addRelation("r_has1", label: "has", to: graph)
        graph = try addRelation("r_has2", label: "has", to: graph)
        graph = try addEdgeConceptToRelation(id: "e1", from: "dog", to: "r_isa1", in: graph)
        graph = try addEdgeRelationToConcept(id: "e2", from: "r_isa1", to: "animal", in: graph)
        graph = try addEdgeConceptToRelation(id: "e3", from: "cat", to: "r_isa2", in: graph)
        graph = try addEdgeRelationToConcept(id: "e4", from: "r_isa2", to: "animal", in: graph)
        graph = try addEdgeConceptToRelation(id: "e5", from: "dog", to: "r_has1", in: graph)
        graph = try addEdgeRelationToConcept(id: "e6", from: "r_has1", to: "fur", in: graph)
        graph = try addEdgeConceptToRelation(id: "e7", from: "cat", to: "r_has2", in: graph)
        graph = try addEdgeRelationToConcept(id: "e8", from: "r_has2", to: "fur", in: graph)

        let groups = findMergeableRelations(in: graph)
        #expect(groups.count == 2)
        let labels = Set(groups.map { $0.label })
        #expect(labels == ["is a", "has"])
    }

    @Test
    func find_mixedMergeableAndNonMergeable() throws(VError) {
        // r1, r2 both -[is a]-> Animal  (mergeable)
        // r3 -[likes]-> Animal          (unique — not mergeable)
        var graph = try createConceptMapGraph()
        graph = try addConcept("dog", label: "Dog", to: graph)
        graph = try addConcept("cat", label: "Cat", to: graph)
        graph = try addConcept("bird", label: "Bird", to: graph)
        graph = try addConcept("animal", label: "Animal", to: graph)
        graph = try addRelation("r1", label: "is a", to: graph)
        graph = try addRelation("r2", label: "is a", to: graph)
        graph = try addRelation("r3", label: "likes", to: graph)
        graph = try addEdgeConceptToRelation(id: "e1", from: "dog", to: "r1", in: graph)
        graph = try addEdgeRelationToConcept(id: "e2", from: "r1", to: "animal", in: graph)
        graph = try addEdgeConceptToRelation(id: "e3", from: "cat", to: "r2", in: graph)
        graph = try addEdgeRelationToConcept(id: "e4", from: "r2", to: "animal", in: graph)
        graph = try addEdgeConceptToRelation(id: "e5", from: "bird", to: "r3", in: graph)
        graph = try addEdgeRelationToConcept(id: "e6", from: "r3", to: "animal", in: graph)

        let groups = findMergeableRelations(in: graph)
        #expect(groups.count == 1)
        #expect(groups[0].label == "is a")
    }

    @Test
    func find_multipleOutgoingTargets_identicalSets() throws(VError) {
        // r1 -> {Weight, Style}, r2 -> {Weight, Style}  — identical target sets
        var graph = try createConceptMapGraph()
        graph = try addConcept("font", label: "Font", to: graph)
        graph = try addConcept("font2", label: "Font2", to: graph)
        graph = try addConcept("weight", label: "Weight", to: graph)
        graph = try addConcept("style", label: "Style", to: graph)
        graph = try addRelation("r1", label: "has", to: graph)
        graph = try addRelation("r2", label: "has", to: graph)
        graph = try addEdgeConceptToRelation(id: "e1", from: "font", to: "r1", in: graph)
        graph = try addEdgeRelationToConcept(id: "e2", from: "r1", to: "weight", in: graph)
        graph = try addEdgeRelationToConcept(id: "e3", from: "r1", to: "style", in: graph)
        graph = try addEdgeConceptToRelation(id: "e4", from: "font2", to: "r2", in: graph)
        graph = try addEdgeRelationToConcept(id: "e5", from: "r2", to: "weight", in: graph)
        graph = try addEdgeRelationToConcept(id: "e6", from: "r2", to: "style", in: graph)

        let groups = findMergeableRelations(in: graph)
        #expect(groups.count == 1)
        #expect(groups[0].targets == Set([Node(string: "weight"), Node(string: "style")]))
    }

    @Test
    func find_nonConceptMapGraph_returnsEmpty() throws(VError) {
        var graph = try VGraph()
            .defineStandardAttributes()
            .add(nodeType: NodeType(string: "MyType"))
        graph = try graph.add(node: Node(string: "n1"), type: NodeType(string: "MyType"))

        let groups = findMergeableRelations(in: graph)
        #expect(groups.isEmpty)
    }

    // MARK: - applyMergeRelations — Transform

    @Test
    func merge_nothingToMerge_graphUnchanged() throws(VError) {
        var graph = try createConceptMapGraph()
        graph = try addConcept("dog", label: "Dog", to: graph)
        graph = try addRelation("r1", label: "is a", to: graph)
        graph = try addConcept("mammal", label: "Mammal", to: graph)
        graph = try addEdgeConceptToRelation(id: "e1", from: "dog", to: "r1", in: graph)
        graph = try addEdgeRelationToConcept(id: "e2", from: "r1", to: "mammal", in: graph)

        let result = try applyMergeRelations(to: graph)

        #expect(result.nodes.count == graph.nodes.count)
        #expect(result.edges.count == graph.edges.count)
    }

    @Test
    func merge_basicPair_nodeCountCorrect() throws(VError) {
        // Dog -[is a]-> Mammal, Cat -[is a]-> Mammal
        var graph = try createConceptMapGraph()
        graph = try addConcept("dog", label: "Dog", to: graph)
        graph = try addConcept("cat", label: "Cat", to: graph)
        graph = try addConcept("mammal", label: "Mammal", to: graph)
        graph = try addRelation("r1", label: "is a", to: graph)
        graph = try addRelation("r2", label: "is a", to: graph)
        graph = try addEdgeConceptToRelation(id: "e1", from: "dog", to: "r1", in: graph)
        graph = try addEdgeRelationToConcept(id: "e2", from: "r1", to: "mammal", in: graph)
        graph = try addEdgeConceptToRelation(id: "e3", from: "cat", to: "r2", in: graph)
        graph = try addEdgeRelationToConcept(id: "e4", from: "r2", to: "mammal", in: graph)

        let result = try applyMergeRelations(to: graph)

        // 5 nodes → 4: dog, cat, mammal, survivor
        #expect(result.nodes.count == 4)
        // 4 edges → 3: the survivor's outgoing edge is kept, duplicate's deleted
        #expect(result.edges.count == 3)
    }

    @Test
    func merge_duplicateNodeIsDeleted_survivorRemains() throws(VError) {
        var graph = try createConceptMapGraph()
        graph = try addConcept("dog", label: "Dog", to: graph)
        graph = try addConcept("cat", label: "Cat", to: graph)
        graph = try addConcept("mammal", label: "Mammal", to: graph)
        graph = try addRelation("r1", label: "is a", to: graph)
        graph = try addRelation("r2", label: "is a", to: graph)
        graph = try addEdgeConceptToRelation(id: "e1", from: "dog", to: "r1", in: graph)
        graph = try addEdgeRelationToConcept(id: "e2", from: "r1", to: "mammal", in: graph)
        graph = try addEdgeConceptToRelation(id: "e3", from: "cat", to: "r2", in: graph)
        graph = try addEdgeRelationToConcept(id: "e4", from: "r2", to: "mammal", in: graph)

        let groups = findMergeableRelations(in: graph)
        let survivor = groups[0].nodes[0]
        let duplicate = groups[0].nodes[1]

        let result = try applyMergeRelations(to: graph)

        #expect(result.has(node: survivor))
        #expect(!result.has(node: duplicate))
    }

    @Test
    func merge_incomingEdgesRedirectedToSurvivor() throws(VError) {
        var graph = try createConceptMapGraph()
        graph = try addConcept("dog", label: "Dog", to: graph)
        graph = try addConcept("cat", label: "Cat", to: graph)
        graph = try addConcept("mammal", label: "Mammal", to: graph)
        graph = try addRelation("r1", label: "is a", to: graph)
        graph = try addRelation("r2", label: "is a", to: graph)
        graph = try addEdgeConceptToRelation(id: "e1", from: "dog", to: "r1", in: graph)
        graph = try addEdgeRelationToConcept(id: "e2", from: "r1", to: "mammal", in: graph)
        graph = try addEdgeConceptToRelation(id: "e3", from: "cat", to: "r2", in: graph)
        graph = try addEdgeRelationToConcept(id: "e4", from: "r2", to: "mammal", in: graph)

        let groups = findMergeableRelations(in: graph)
        let survivor = groups[0].nodes[0]

        let result = try applyMergeRelations(to: graph)

        // e3 (cat → r2) should now point to the survivor
        let e3 = result.get(edge: Edge.Id(string: "e3"))!
        #expect(e3.from == Node(string: "cat"))
        #expect(e3.to == survivor)
    }

    @Test
    func merge_survivorOutgoingEdgePreserved() throws(VError) {
        var graph = try createConceptMapGraph()
        graph = try addConcept("dog", label: "Dog", to: graph)
        graph = try addConcept("cat", label: "Cat", to: graph)
        graph = try addConcept("mammal", label: "Mammal", to: graph)
        graph = try addRelation("r1", label: "is a", to: graph)
        graph = try addRelation("r2", label: "is a", to: graph)
        graph = try addEdgeConceptToRelation(id: "e1", from: "dog", to: "r1", in: graph)
        graph = try addEdgeRelationToConcept(id: "e2", from: "r1", to: "mammal", in: graph)
        graph = try addEdgeConceptToRelation(id: "e3", from: "cat", to: "r2", in: graph)
        graph = try addEdgeRelationToConcept(id: "e4", from: "r2", to: "mammal", in: graph)

        let groups = findMergeableRelations(in: graph)
        let survivor = groups[0].nodes[0]

        let result = try applyMergeRelations(to: graph)

        let outgoing = result.edges.filter { $0.from == survivor }
        #expect(outgoing.count == 1)
        #expect(outgoing[0].to == Node(string: "mammal"))
    }

    @Test
    func merge_duplicateOutgoingEdgeDeleted() throws(VError) {
        var graph = try createConceptMapGraph()
        graph = try addConcept("dog", label: "Dog", to: graph)
        graph = try addConcept("cat", label: "Cat", to: graph)
        graph = try addConcept("mammal", label: "Mammal", to: graph)
        graph = try addRelation("r1", label: "is a", to: graph)
        graph = try addRelation("r2", label: "is a", to: graph)
        graph = try addEdgeConceptToRelation(id: "e1", from: "dog", to: "r1", in: graph)
        graph = try addEdgeRelationToConcept(id: "e2", from: "r1", to: "mammal", in: graph)
        graph = try addEdgeConceptToRelation(id: "e3", from: "cat", to: "r2", in: graph)
        graph = try addEdgeRelationToConcept(id: "e4", from: "r2", to: "mammal", in: graph)

        let groups = findMergeableRelations(in: graph)
        let duplicate = groups[0].nodes[1]

        let result = try applyMergeRelations(to: graph)

        // The duplicate's outgoing edge (relation→mammal) should be deleted.
        // The survivor's outgoing edge should remain.
        let duplicateOutgoingId: String
        let survivorOutgoingId: String
        if duplicate == Node(string: "r2") {
            duplicateOutgoingId = "e4"
            survivorOutgoingId = "e2"
        } else {
            duplicateOutgoingId = "e2"
            survivorOutgoingId = "e4"
        }
        #expect(!result.has(edge: Edge.Id(string: duplicateOutgoingId)))
        #expect(result.has(edge: Edge.Id(string: survivorOutgoingId)))
    }

    @Test
    func merge_redirectedEdgePreservesEdgeType() throws(VError) {
        var graph = try createConceptMapGraph()
        graph = try addConcept("dog", label: "Dog", to: graph)
        graph = try addConcept("cat", label: "Cat", to: graph)
        graph = try addConcept("mammal", label: "Mammal", to: graph)
        graph = try addRelation("r1", label: "is a", to: graph)
        graph = try addRelation("r2", label: "is a", to: graph)
        graph = try addEdgeConceptToRelation(id: "e1", from: "dog", to: "r1", in: graph)
        graph = try addEdgeRelationToConcept(id: "e2", from: "r1", to: "mammal", in: graph)
        graph = try addEdgeConceptToRelation(id: "e3", from: "cat", to: "r2", in: graph)
        graph = try addEdgeRelationToConcept(id: "e4", from: "r2", to: "mammal", in: graph)

        let result = try applyMergeRelations(to: graph)

        // e3 was redirected — should still be conceptToRelation
        let e3EdgeType = try result.edgeType(for: Edge.Id(string: "e3"))
        #expect(e3EdgeType.id == CM.EdgeTypes.conceptToRelation.id)
    }

    @Test
    func merge_redirectedEdgeFromEmphasizedConcept_preservesEdgeType() throws(VError) {
        var graph = try createConceptMapGraph()
        graph = try addEmphasizedConcept("ec1", label: "Key1", to: graph)
        graph = try addEmphasizedConcept("ec2", label: "Key2", to: graph)
        graph = try addConcept("target", label: "Target", to: graph)
        graph = try addRelation("r1", label: "leads to", to: graph)
        graph = try addRelation("r2", label: "leads to", to: graph)
        graph = try addEdgeEmphasizedConceptToRelation(id: "e1", from: "ec1", to: "r1", in: graph)
        graph = try addEdgeRelationToConcept(id: "e2", from: "r1", to: "target", in: graph)
        graph = try addEdgeEmphasizedConceptToRelation(id: "e3", from: "ec2", to: "r2", in: graph)
        graph = try addEdgeRelationToConcept(id: "e4", from: "r2", to: "target", in: graph)

        let result = try applyMergeRelations(to: graph)

        // e3 redirected — should still be emphasizedConceptToRelation
        let e3EdgeType = try result.edgeType(for: Edge.Id(string: "e3"))
        #expect(e3EdgeType.id == CM.EdgeTypes.emphasizedConceptToRelation.id)
    }

    @Test
    func merge_survivorLabelPreserved() throws(VError) {
        var graph = try createConceptMapGraph()
        graph = try addConcept("dog", label: "Dog", to: graph)
        graph = try addConcept("cat", label: "Cat", to: graph)
        graph = try addConcept("mammal", label: "Mammal", to: graph)
        graph = try addRelation("r1", label: "is a", to: graph)
        graph = try addRelation("r2", label: "is a", to: graph)
        graph = try addEdgeConceptToRelation(id: "e1", from: "dog", to: "r1", in: graph)
        graph = try addEdgeRelationToConcept(id: "e2", from: "r1", to: "mammal", in: graph)
        graph = try addEdgeConceptToRelation(id: "e3", from: "cat", to: "r2", in: graph)
        graph = try addEdgeRelationToConcept(id: "e4", from: "r2", to: "mammal", in: graph)

        let groups = findMergeableRelations(in: graph)
        let survivor = groups[0].nodes[0]

        let result = try applyMergeRelations(to: graph)

        let label: String = try result.get(node: survivor, attribute: Attributes.Node.label)
        #expect(label == "is a")
    }

    @Test
    func merge_survivorNodeTypeIsStillRelation() throws(VError) {
        var graph = try createConceptMapGraph()
        graph = try addConcept("dog", label: "Dog", to: graph)
        graph = try addConcept("cat", label: "Cat", to: graph)
        graph = try addConcept("mammal", label: "Mammal", to: graph)
        graph = try addRelation("r1", label: "is a", to: graph)
        graph = try addRelation("r2", label: "is a", to: graph)
        graph = try addEdgeConceptToRelation(id: "e1", from: "dog", to: "r1", in: graph)
        graph = try addEdgeRelationToConcept(id: "e2", from: "r1", to: "mammal", in: graph)
        graph = try addEdgeConceptToRelation(id: "e3", from: "cat", to: "r2", in: graph)
        graph = try addEdgeRelationToConcept(id: "e4", from: "r2", to: "mammal", in: graph)

        let groups = findMergeableRelations(in: graph)
        let survivor = groups[0].nodes[0]

        let result = try applyMergeRelations(to: graph)

        let nodeType = try result.nodeType(for: survivor)
        #expect(nodeType == CM.NodeTypes.relation)
    }

    @Test
    func merge_conceptNodesUntouched() throws(VError) {
        var graph = try createConceptMapGraph()
        graph = try addConcept("dog", label: "Dog", to: graph)
        graph = try addConcept("cat", label: "Cat", to: graph)
        graph = try addConcept("mammal", label: "Mammal", to: graph)
        graph = try addRelation("r1", label: "is a", to: graph)
        graph = try addRelation("r2", label: "is a", to: graph)
        graph = try addEdgeConceptToRelation(id: "e1", from: "dog", to: "r1", in: graph)
        graph = try addEdgeRelationToConcept(id: "e2", from: "r1", to: "mammal", in: graph)
        graph = try addEdgeConceptToRelation(id: "e3", from: "cat", to: "r2", in: graph)
        graph = try addEdgeRelationToConcept(id: "e4", from: "r2", to: "mammal", in: graph)

        let result = try applyMergeRelations(to: graph)

        #expect(result.has(node: Node(string: "dog")))
        #expect(result.has(node: Node(string: "cat")))
        #expect(result.has(node: Node(string: "mammal")))
        let dogLabel: String = try result.get(node: Node(string: "dog"), attribute: Attributes.Node.label)
        #expect(dogLabel == "Dog")
    }

    @Test
    func merge_threeWay_twoNodesRemoved() throws(VError) {
        var graph = try createConceptMapGraph()
        graph = try addConcept("dog", label: "Dog", to: graph)
        graph = try addConcept("cat", label: "Cat", to: graph)
        graph = try addConcept("fish", label: "Fish", to: graph)
        graph = try addConcept("animal", label: "Animal", to: graph)
        graph = try addRelation("r1", label: "is a", to: graph)
        graph = try addRelation("r2", label: "is a", to: graph)
        graph = try addRelation("r3", label: "is a", to: graph)
        graph = try addEdgeConceptToRelation(id: "e1", from: "dog", to: "r1", in: graph)
        graph = try addEdgeRelationToConcept(id: "e2", from: "r1", to: "animal", in: graph)
        graph = try addEdgeConceptToRelation(id: "e3", from: "cat", to: "r2", in: graph)
        graph = try addEdgeRelationToConcept(id: "e4", from: "r2", to: "animal", in: graph)
        graph = try addEdgeConceptToRelation(id: "e5", from: "fish", to: "r3", in: graph)
        graph = try addEdgeRelationToConcept(id: "e6", from: "r3", to: "animal", in: graph)

        let groups = findMergeableRelations(in: graph)
        let survivor = groups[0].nodes[0]

        let result = try applyMergeRelations(to: graph)

        // 7 → 5 nodes, 6 → 4 edges
        #expect(result.nodes.count == 5)
        #expect(result.edges.count == 4)

        let incomingToSurvivor = result.edges.filter { $0.to == survivor }
        #expect(incomingToSurvivor.count == 3)  // dog, cat, fish all → survivor
    }

    @Test
    func merge_nonMergeableRelationUnaffected() throws(VError) {
        // r1, r2 merge (both "is a" → Animal). r3 ("likes" → Animal) stays.
        var graph = try createConceptMapGraph()
        graph = try addConcept("dog", label: "Dog", to: graph)
        graph = try addConcept("cat", label: "Cat", to: graph)
        graph = try addConcept("bird", label: "Bird", to: graph)
        graph = try addConcept("animal", label: "Animal", to: graph)
        graph = try addRelation("r1", label: "is a", to: graph)
        graph = try addRelation("r2", label: "is a", to: graph)
        graph = try addRelation("r3", label: "likes", to: graph)
        graph = try addEdgeConceptToRelation(id: "e1", from: "dog", to: "r1", in: graph)
        graph = try addEdgeRelationToConcept(id: "e2", from: "r1", to: "animal", in: graph)
        graph = try addEdgeConceptToRelation(id: "e3", from: "cat", to: "r2", in: graph)
        graph = try addEdgeRelationToConcept(id: "e4", from: "r2", to: "animal", in: graph)
        graph = try addEdgeConceptToRelation(id: "e5", from: "bird", to: "r3", in: graph)
        graph = try addEdgeRelationToConcept(id: "e6", from: "r3", to: "animal", in: graph)

        let result = try applyMergeRelations(to: graph)

        #expect(result.has(node: Node(string: "r3")))
        let e5 = result.get(edge: Edge.Id(string: "e5"))!
        #expect(e5.from == Node(string: "bird"))
        #expect(e5.to == Node(string: "r3"))
        let e6 = result.get(edge: Edge.Id(string: "e6"))!
        #expect(e6.from == Node(string: "r3"))
        #expect(e6.to == Node(string: "animal"))
    }

    @Test
    func merge_multipleTargets_allOutgoingSurvive() throws(VError) {
        // r1, r2 both → {Weight, Style}
        var graph = try createConceptMapGraph()
        graph = try addConcept("font", label: "Font", to: graph)
        graph = try addConcept("font2", label: "Font2", to: graph)
        graph = try addConcept("weight", label: "Weight", to: graph)
        graph = try addConcept("style", label: "Style", to: graph)
        graph = try addRelation("r1", label: "has", to: graph)
        graph = try addRelation("r2", label: "has", to: graph)
        graph = try addEdgeConceptToRelation(id: "e1", from: "font", to: "r1", in: graph)
        graph = try addEdgeRelationToConcept(id: "e2", from: "r1", to: "weight", in: graph)
        graph = try addEdgeRelationToConcept(id: "e3", from: "r1", to: "style", in: graph)
        graph = try addEdgeConceptToRelation(id: "e4", from: "font2", to: "r2", in: graph)
        graph = try addEdgeRelationToConcept(id: "e5", from: "r2", to: "weight", in: graph)
        graph = try addEdgeRelationToConcept(id: "e6", from: "r2", to: "style", in: graph)

        let groups = findMergeableRelations(in: graph)
        let survivor = groups[0].nodes[0]

        let result = try applyMergeRelations(to: graph)

        let outgoing = result.edges.filter { $0.from == survivor }
        #expect(outgoing.count == 2)
        let outgoingTargets = Set(outgoing.map { $0.to })
        #expect(outgoingTargets == Set([Node(string: "weight"), Node(string: "style")]))

        let incoming = result.edges.filter { $0.to == survivor }
        #expect(incoming.count == 2)
    }

    @Test
    func merge_withEmphasizedConceptTarget() throws(VError) {
        var graph = try createConceptMapGraph()
        graph = try addConcept("dog", label: "Dog", to: graph)
        graph = try addConcept("cat", label: "Cat", to: graph)
        graph = try addEmphasizedConcept("practice", label: "Practice", to: graph)
        graph = try addRelation("r1", label: "requires", to: graph)
        graph = try addRelation("r2", label: "requires", to: graph)
        graph = try addEdgeConceptToRelation(id: "e1", from: "dog", to: "r1", in: graph)
        graph = try addEdgeRelationToEmphasizedConcept(id: "e2", from: "r1", to: "practice", in: graph)
        graph = try addEdgeConceptToRelation(id: "e3", from: "cat", to: "r2", in: graph)
        graph = try addEdgeRelationToEmphasizedConcept(id: "e4", from: "r2", to: "practice", in: graph)

        let result = try applyMergeRelations(to: graph)

        #expect(result.nodes.count == 4)

        let groups = findMergeableRelations(in: graph)
        let survivor = groups[0].nodes[0]
        let outgoing = result.edges.filter { $0.from == survivor }
        #expect(outgoing.count == 1)
        let outEdgeType = try result.edgeType(for: outgoing[0])
        #expect(outEdgeType.id == CM.EdgeTypes.relationToEmphasizedConcept.id)
    }

    // MARK: - Complete Structure Verification

    @Test
    func merge_allPropositionsIntact() throws(VError) {
        // Before:
        //   Dog -[is a]-> Mammal   (propositions: "Dog is a Mammal")
        //   Cat -[is a]-> Mammal   (propositions: "Cat is a Mammal")
        // After merge:
        //   Dog -[is a]-> Mammal   (proposition: "Dog is a Mammal")
        //   Cat -[is a]-> Mammal   (proposition: "Cat is a Mammal")
        //   … but through a SINGLE "is a" Relation node
        var graph = try createConceptMapGraph()
        graph = try addConcept("dog", label: "Dog", to: graph)
        graph = try addConcept("cat", label: "Cat", to: graph)
        graph = try addConcept("mammal", label: "Mammal", to: graph)
        graph = try addRelation("r1", label: "is a", to: graph)
        graph = try addRelation("r2", label: "is a", to: graph)
        graph = try addEdgeConceptToRelation(id: "e1", from: "dog", to: "r1", in: graph)
        graph = try addEdgeRelationToConcept(id: "e2", from: "r1", to: "mammal", in: graph)
        graph = try addEdgeConceptToRelation(id: "e3", from: "cat", to: "r2", in: graph)
        graph = try addEdgeRelationToConcept(id: "e4", from: "r2", to: "mammal", in: graph)

        let result = try applyMergeRelations(to: graph)

        let relationNodes = result.nodes.filter { (try? result.nodeType(for: $0)) == CM.NodeTypes.relation }
        #expect(relationNodes.count == 1)
        let relation = relationNodes[0]

        let incoming = result.edges.filter { $0.to == relation }
        let incomingSources = Set(incoming.map { $0.from })
        #expect(incomingSources == Set([Node(string: "dog"), Node(string: "cat")]))

        let outgoing = result.edges.filter { $0.from == relation }
        #expect(outgoing.count == 1)
        #expect(outgoing[0].to == Node(string: "mammal"))

        for edge in incoming {
            let edgeType = try result.edgeType(for: edge)
            #expect(edgeType.from == CM.NodeTypes.concept)
            #expect(edgeType.to == CM.NodeTypes.relation)
        }
        for edge in outgoing {
            let edgeType = try result.edgeType(for: edge)
            #expect(edgeType.from == CM.NodeTypes.relation)
            #expect(edgeType.to == CM.NodeTypes.concept)
        }
    }

    // MARK: - Pipeline Integration

    @Test
    func merge_composesInPipeline() throws(VError) {
        var graph = try createConceptMapGraph()
        graph = try addConcept("dog", label: "Dog", to: graph)
        graph = try addConcept("cat", label: "Cat", to: graph)
        graph = try addConcept("mammal", label: "Mammal", to: graph)
        graph = try addRelation("r1", label: "is a", to: graph)
        graph = try addRelation("r2", label: "is a", to: graph)
        graph = try addEdgeConceptToRelation(id: "e1", from: "dog", to: "r1", in: graph)
        graph = try addEdgeRelationToConcept(id: "e2", from: "r1", to: "mammal", in: graph)
        graph = try addEdgeConceptToRelation(id: "e3", from: "cat", to: "r2", in: graph)
        graph = try addEdgeRelationToConcept(id: "e4", from: "r2", to: "mammal", in: graph)

        let pipeline = TransformPipeline.compose(
            applyMergeRelations,
            applyFoldingLayoutStep
        )
        let result = try pipeline(graph)

        #expect(result.nodes.count == 4)
    }

    @Test
    func merge_notationDispatcherAppliesMerge() throws(VError) {
        var graph = try createConceptMapGraph()
        graph = try addConcept("dog", label: "Dog", to: graph)
        graph = try addConcept("cat", label: "Cat", to: graph)
        graph = try addConcept("mammal", label: "Mammal", to: graph)
        graph = try addRelation("r1", label: "is a", to: graph)
        graph = try addRelation("r2", label: "is a", to: graph)
        graph = try addEdgeConceptToRelation(id: "e1", from: "dog", to: "r1", in: graph)
        graph = try addEdgeRelationToConcept(id: "e2", from: "r1", to: "mammal", in: graph)
        graph = try addEdgeConceptToRelation(id: "e3", from: "cat", to: "r2", in: graph)
        graph = try addEdgeRelationToConcept(id: "e4", from: "r2", to: "mammal", in: graph)

        let result = try Notations.notationTransformsStep(graph)

        #expect(result.nodes.count == 4)
    }

    @Test
    func merge_nonConceptMapNotation_notDispatched() throws(VError) {
        var graph = try VGraph()
            .defineStandardAttributes()
        graph = try Notations.Ibis.addNotation(addTo: graph)
        graph = graph.using(notation: "IBIS")

        let result = try Notations.notationTransformsStep(graph)

        #expect(result.nodes.count == graph.nodes.count)
    }

    // MARK: - Which node survives

    /// The pair is declared in *both* orders on purpose. Swift seeds its hasher
    /// per process, so merging the same pair twice in one test can agree with
    /// itself while still following hash order; requiring each declaration order
    /// to elect its own first node cannot.
    private func twoIdenticalRelations(firstDeclared: String, secondDeclared: String) throws(VError) -> VGraph {
        var graph = try createConceptMapGraph()
        graph = try addConcept("source1", label: "Source One", to: graph)
        graph = try addConcept("source2", label: "Source Two", to: graph)
        graph = try addConcept("target", label: "Target", to: graph)
        graph = try addRelation(firstDeclared, label: "serializes", to: graph)
        graph = try addRelation(secondDeclared, label: "serializes", to: graph)
        graph = try addEdgeConceptToRelation(id: "e1", from: "source1", to: firstDeclared, in: graph)
        graph = try addEdgeRelationToConcept(id: "e2", from: firstDeclared, to: "target", in: graph)
        graph = try addEdgeConceptToRelation(id: "e3", from: "source2", to: secondDeclared, in: graph)
        graph = try addEdgeRelationToConcept(id: "e4", from: secondDeclared, to: "target", in: graph)
        return graph
    }

    @Test("The first declared of two identical relations is the survivor")
    func theEarlierDeclarationSurvives() throws(VError) {
        for (first, second) in [("r24", "r25"), ("r25", "r24")] {
            let graph = try twoIdenticalRelations(firstDeclared: first, secondDeclared: second)

            let groups = findMergeableRelations(in: graph)
            #expect(groups.count == 1)
            #expect(groups.first?.nodes.map { $0.id.description } == [first, second])

            let merged = try applyMergeRelations(to: graph)
            let survivingRelations = merged.nodes
                .filter { (try? merged.nodeType(for: $0)) == CM.NodeTypes.relation }
                .map { $0.id.description }
            #expect(survivingRelations == [first])
        }
    }

    /// Independent of each other, but the order they apply in reaches the store.
    @Test("Mergeable groups come back in a stable order")
    func groupsAreOrdered() throws(VError) {
        var graph = try createConceptMapGraph()
        graph = try addConcept("s", label: "S", to: graph)
        graph = try addConcept("t", label: "T", to: graph)
        for (index, label) in ["zebra", "alpha", "middle"].enumerated() {
            let a = "ra\(index)"
            let b = "rb\(index)"
            graph = try addRelation(a, label: label, to: graph)
            graph = try addRelation(b, label: label, to: graph)
            graph = try addEdgeConceptToRelation(id: "ea\(index)", from: "s", to: a, in: graph)
            graph = try addEdgeRelationToConcept(id: "eb\(index)", from: a, to: "t", in: graph)
            graph = try addEdgeConceptToRelation(id: "ec\(index)", from: "s", to: b, in: graph)
            graph = try addEdgeRelationToConcept(id: "ed\(index)", from: b, to: "t", in: graph)
        }

        let labels = findMergeableRelations(in: graph).map { $0.label }
        #expect(labels == ["alpha", "middle", "zebra"])
    }
}
