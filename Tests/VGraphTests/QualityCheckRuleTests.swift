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
            ("exactlyOne(Goal)", "A diagram has exactly one Goal."),
            ("exactlyOne(CriticalSuccessFactor)", "A diagram has exactly one Critical Success Factor."),
            ("nodeCountRange(Battle, 1, 20)", "A diagram has between 1 and 20 Battle nodes."),
            ("nodeCountRange(Battle, 2, 5)", "A diagram has between two and five Battle nodes."),
            ("labelLength(5)", "Every node's label has at most five words."),
        ])
    func namedCheckRule(spec: String, rule: String) throws {
        let check = try QualityCheckRegistry.resolve(QualityCheckSpec.parse(spec))
        #expect(check.rule == rule)
        #expect(check.name == QualityCheckSpec.parse(spec).name)
    }

    @Test("A notation can call its diagram by its own name")
    func diagramNamedByItsNotation() {
        #expect(QualityCheckRegistry.exactlyOneCheck(nodeTypeName: "Goal", in: "Goal Tree").rule == "A Goal Tree has exactly one Goal.")
    }

    // MARK: - What a notation lists

    @Test("IBIS lists the check it names, then its own")
    func ibisRules() {
        #expect(
            Notations.statedRules(of: Notations.Ibis.entry).map { $0.check }
                == ["noParallelEdges", "treeStructure", "unansweredQuestions"])
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
        #expect(
            Notations.statedRules(of: CM.entry).compactMap { $0.check }
                == ["noParallelEdges"] + CM.entry.qualityChecks.map { $0.name })
    }

    @Test("C4 lists where each detail type belongs")
    func c4ListsItsNesting() {
        let rules = Notations.rules(of: Notations.C4.entry)
        for rule in [
            "A Container belongs inside a Software System.",
            "A Database belongs inside a Software System.",
            "A Component belongs inside a Container.",
            "A Code Element belongs inside a Component.",
        ] {
            #expect(rules.contains(rule), "\(rule) missing from \(rules)")
        }
    }

    @Test("Arithmetic lists its bounds beside its own check")
    func arithmeticListsItsBounds() {
        let rules = Notations.rules(of: Notations.Arithmetic.entry)
        #expect(Notations.statedRules(of: Notations.Arithmetic.entry).contains { $0.check == "divisionByZero" })
        #expect(rules.contains("A Plus has at most one first operand, one second operand and one result."))
        #expect(rules.count == 1 + 4)
    }

    @Test("A rule from a check carries the check and its counterexample; a bound or nesting rule neither")
    func statedRules() throws {
        let entry = Notations.C4.entry
        let stated = Notations.statedRules(of: entry)
        #expect(stated.map { $0.rule } == Notations.rules(of: entry))
        let labelled = try #require(stated.first { $0.check == "unlabeledRelationship" })
        #expect(labelled.counterexample == entry.counterexamples.first { $0.check == "unlabeledRelationship" }?.source)
        #expect(labelled.counterexample != nil)
        let nesting = try #require(stated.first { $0.rule == "A Container belongs inside a Software System." })
        #expect(nesting.check == nil && nesting.counterexample == nil)
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
            ([Attributes.Edge.outDegreeMin(1)], "A Concept has at least one outgoing \"concept to relation\" edge."),
            ([Attributes.Edge.inDegreeMax(3)], "A Relation has at most three incoming \"concept to relation\" edges."),
            (
                [Attributes.Edge.inDegreeMin(2), Attributes.Edge.inDegreeMax(2)],
                "A Relation has exactly two incoming \"concept to relation\" edges."
            ),
            (
                [Attributes.Edge.outDegreeMin(1), Attributes.Edge.outDegreeMax(4)],
                "A Concept has between one and four outgoing \"concept to relation\" edges."
            ),
            (
                [Attributes.Edge.samePairMax(1)],
                "A Concept and a Relation are joined by at most one \"concept to relation\" edge."
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
        #expect(Bound.rules(in: graph) == ["A Relation has at least one incoming edge."])
    }

    @Test("Limits on one type read as one sentence")
    func boundsOnOneTypeMerge() throws {
        let graph = try conceptMap()
            .setting(edgeType: CM.EdgeTypes.conceptToRelation, attribute: Attributes.Edge.inDegreeMax(3))
            .setting(nodeType: CM.NodeTypes.relation, attribute: Attributes.Node.totalInDegreeMin(1))
        #expect(
            Bound.rules(in: graph) == [
                "A Relation has at most three incoming \"concept to relation\" edges and at least one incoming edge."
            ])
    }

    @Test("A large number stays in digits")
    func largeNumbers() throws {
        let graph = try bounded([Attributes.Edge.inDegreeMax(12)], on: CM.EdgeTypes.conceptToRelation)
        #expect(Bound.rules(in: graph) == ["A Relation has at most 12 incoming \"concept to relation\" edges."])
    }

    @Test("A notation with no bounds lists none")
    func noBounds() throws {
        #expect(Bound.rules(in: try conceptMap()).isEmpty)
    }
}
