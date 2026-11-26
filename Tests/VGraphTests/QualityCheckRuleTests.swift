//
//  QualityCheckRuleTests.swift
//  VGraph
//
//  The sentence each [[Quality check]] states, and the rules a notation lists
//  from them, its bounds and its detailings. The website and the MCP server
//  print these words as they are.
//

import TestSupport
import Testing

@testable import VGraph

@Suite("Quality check rules")
struct QualityCheckRuleTests {

    typealias CM = Notations.ConceptMap

    // MARK: - Every check states a rule

    @Test("Every check a built-in notation runs states its rule in one sentence")
    func everyNotationCheckStatesARule() {
        for (id, entry) in NotationRegistry.entries {
            let names = entry.qualityChecks.map { $0.name }
            #expect(Set(names).count == names.count, "\(id) names a check twice: \(names)")
            for check in entry.qualityChecks {
                #expect(!check.name.isEmpty, "\(id) has a check without a name")
                #expect(check.rule.hasSuffix("."), "\(id)/\(check.name): \"\(check.rule)\"")
                #expect(check.rule.count > 10, "\(id)/\(check.name): \"\(check.rule)\"")
            }
        }
    }

    @Test("Every check that runs for every notation states its rule")
    func everyGenericCheckStatesARule() {
        let names = GenericQualityChecks.all.map { $0.name }
        #expect(Set(names).count == names.count)
        for check in GenericQualityChecks.all {
            #expect(check.rule.hasSuffix("."), "\(check.name): \"\(check.rule)\"")
        }
    }

    @Test(
        "A check a vnotation names states its rule with the numbers it was given",
        arguments: [
            ("treeStructure", "Every node has at most one parent."),
            ("noParallelEdges", "At most one edge joins two nodes in the same direction."),
            ("exactlyOne(Goal)", "A diagram has exactly one Goal."),
            ("nodeCountRange(Battle, 1, 20)", "A diagram has between 1 and 20 Battle nodes."),
            ("labelLength(5)", "Every node's label has at most 5 words."),
        ])
    func namedCheckRule(spec: String, rule: String) throws {
        let check = try QualityCheckRegistry.resolve(QualityCheckSpec.parse(spec))
        #expect(check.rule == rule)
        #expect(check.name == QualityCheckSpec.parse(spec).name)
    }

    // MARK: - What a notation lists

    @Test("IBIS lists the check it names, then its own")
    func ibisRules() {
        #expect(
            Notations.rules(of: Notations.Ibis.entry) == [
                "At most one edge joins two nodes in the same direction.",
                "Every node has at most one parent.",
                "Every Question has at least one Answer.",
            ])
    }

    /// The checks every notation runs are told once, not repeated per notation.
    @Test("A notation's list leaves out the checks every notation runs")
    func genericChecksAreNotListedPerNotation() {
        let generic = Set(GenericQualityChecks.all.map { $0.rule })
        for (id, entry) in NotationRegistry.entries {
            let listed = Notations.rules(of: entry).filter { generic.contains($0) }
            #expect(listed.isEmpty, "\(id) repeats \(listed)")
        }
    }

    @Test("A metric is not a rule: Concept Map lists no ratio")
    func metricsAreNotListed() {
        let rules = Notations.rules(of: CM.entry)
        #expect(!rules.contains { $0.contains("Ratio") || $0.contains("ratio") })
        #expect(rules.contains("Every concept's label has at most 3 words."))
        #expect(rules.contains("A map has between 5 and 25 concepts."))
    }

    @Test("C4 lists where each detail type belongs")
    func c4ListsItsNesting() {
        let rules = Notations.rules(of: Notations.C4.entry)
        for rule in [
            "Every relationship has a label saying what it is for.",
            "A Container belongs inside a SoftwareSystem.",
            "A Database belongs inside a SoftwareSystem.",
            "A Component belongs inside a Container.",
            "A CodeElement belongs inside a Component.",
        ] {
            #expect(rules.contains(rule), "\(rule) missing from \(rules)")
        }
    }

    @Test("Arithmetic lists its bounds beside its own check")
    func arithmeticListsItsBounds() {
        let rules = Notations.rules(of: Notations.Arithmetic.entry)
        #expect(rules.contains("A Divide never divides by zero."))
        #expect(rules.contains("A Plus has at most 1 incoming \"plus_first_operand\" edge."))
        #expect(rules.contains("A Plus has at most 1 outgoing \"plus_result\" edge."))
    }

    // MARK: - How a bound reads

    private func conceptMap() throws(VError) -> VGraph {
        try CM.addNotation(to: VGraph()).using(notation: "ConceptMap")
    }

    private func bounded(_ bounds: [Attribute], on edgeType: EdgeType) throws -> VGraph {
        var graph = try conceptMap()
        for bound in bounds { graph = try graph.setting(edgeType: edgeType, attribute: bound) }
        return graph
    }

    @Test("A bound reads as its range")
    func boundRanges() throws {
        let edge = CM.EdgeTypes.conceptToRelation
        let rows: [([Attribute], String)] = [
            ([Attributes.Edge.outDegreeMin(1)], "A Concept has at least 1 outgoing \"concept_to_relation\" edge."),
            ([Attributes.Edge.inDegreeMax(3)], "A Relation has at most 3 incoming \"concept_to_relation\" edges."),
            (
                [Attributes.Edge.inDegreeMin(2), Attributes.Edge.inDegreeMax(2)],
                "A Relation has exactly 2 incoming \"concept_to_relation\" edges."
            ),
            (
                [Attributes.Edge.outDegreeMin(1), Attributes.Edge.outDegreeMax(4)],
                "A Concept has between 1 and 4 outgoing \"concept_to_relation\" edges."
            ),
            (
                [Attributes.Edge.samePairMax(1)],
                "A Concept and a Relation are joined by at most 1 \"concept_to_relation\" edge."
            ),
        ]
        for (bounds, sentence) in rows {
            #expect(Bound.rules(in: try bounded(bounds, on: edge)) == [sentence])
        }
    }

    @Test("A bound on a node type counts edges of every type")
    func nodeTypeBound() throws {
        let graph = try conceptMap().setting(
            nodeType: CM.NodeTypes.relation, attribute: Attributes.Node.totalInDegreeMin(1))
        #expect(Bound.rules(in: graph) == ["A Relation has at least 1 incoming edge."])
    }

    @Test("A notation with no bounds lists none")
    func noBounds() throws {
        #expect(Bound.rules(in: try conceptMap()).isEmpty)
    }
}
