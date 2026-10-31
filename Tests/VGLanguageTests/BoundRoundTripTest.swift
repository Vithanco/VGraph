//
//  BoundRoundTripTest.swift
//  VGraph
//
//  ADR-0011: a notation declares its bounds as attributes, so a
//  `vnotation` block must both accept them and re-emit them. Neither side is
//  generic — `applyEdgeTypeAttributes` matches on the attribute name and
//  `reconstructEdgeTypeSpec` writes it — so a bound that parses but does not
//  export (or the reverse) is the failure this file exists to catch.
//

import Testing

@testable import VGLanguage
@testable import VGraph

@Suite("Bound round trip through vnotation")
struct BoundRoundTripTest {

    private func parse(_ source: String) throws -> VGraph {
        try VGraphParser(logger: NoOpLogger()).parse(source: source)
    }

    private func roundTrip(_ source: String) throws -> String {
        try VGLExporter().export(graph: parse(source))
    }

    /// A notation with one bounded edge type. `Question -> Answer` with `outDegreeMin: 1`
    /// is the IBIS rule from ADR-0011, expressed here in a standalone vnotation so
    /// the test does not depend on IBIS adopting it.
    private let bounded = """
        vnotation Bounded {
            node type: Question [nodeStyle: bareText, color: "#336699"]
            node type: Answer [nodeStyle: bareText, color: "#669933"]

            edge type: answeredBy  from: Question  to: Answer [outDegreeMin: 1, samePairMax: 1]
        }
        vgraph t: Bounded "T" {
            node q1: Question "Should we rewrite?";
            node a1: Answer "No";
            edge q1 -> a1;
        }
        """

    @Test("A declared bound reaches the graph")
    func boundIsParsed() throws {
        let graph = try parse(bounded)
        let outDegreeMin = try graph.get(edgeType: EdgeType.Id(rawValue: "answeredBy"), attribute: Attributes.Edge.outDegreeMin)
        let samePairMax = try graph.get(edgeType: EdgeType.Id(rawValue: "answeredBy"), attribute: Attributes.Edge.samePairMax)

        #expect(outDegreeMin == 1)
        #expect(samePairMax == 1)
    }

    @Test("An undeclared bound stays unbounded")
    func undeclaredBoundIsUnbounded() throws {
        let graph = try parse(bounded)
        let inDegreeMax = try graph.get(edgeType: EdgeType.Id(rawValue: "answeredBy"), attribute: Attributes.Edge.inDegreeMax)

        #expect(inDegreeMax == Bound.unbounded)
    }

    @Test("A declared bound is re-emitted")
    func boundIsExported() throws {
        let out = try roundTrip(bounded)

        #expect(out.contains("outDegreeMin: 1"))
        #expect(out.contains("samePairMax: 1"))
    }

    /// The property that matters: export then reparse must not lose the bound.
    @Test("A bound survives export and reparse")
    func boundSurvivesReparse() throws {
        let once = try roundTrip(bounded)
        let graph = try parse(once)

        let outDegreeMin = try graph.get(edgeType: EdgeType.Id(rawValue: "answeredBy"), attribute: Attributes.Edge.outDegreeMin)
        #expect(outDegreeMin == 1)
        // And the text is a fixed point, as every other round trip here is.
        #expect(try roundTrip(once) == once)
    }

    @Test("An unbounded edge type emits no bound attributes")
    func unboundedEmitsNothing() throws {
        let out = try roundTrip(
            """
            vnotation Plain {
                node type: A [nodeStyle: bareText, color: "#336699"]
                edge type: aToA  from: A  to: A
            }
            vgraph t: Plain "T" {
                node a1: A "One";
            }
            """)

        #expect(!out.contains("outDegreeMin"))
        #expect(!out.contains("outDegreeMax"))
        #expect(!out.contains("samePairMax"))
    }

    @Test("A node-type aggregate bound round-trips")
    func nodeTypeBoundRoundTrips() throws {
        let source = """
            vnotation Bounded {
                node type: A [nodeStyle: bareText, color: "#336699", totalOutDegreeMin: 1]
                edge type: aToA  from: A  to: A
            }
            vgraph t: Bounded "T" {
                node a1: A "One";
            }
            """
        let graph = try parse(source)
        #expect(try graph.get(nodeType: NodeType(string: "A"), attribute: Attributes.Node.totalOutDegreeMin) == 1)

        let out = try roundTrip(source)
        #expect(out.contains("totalOutDegreeMin: 1"))
        #expect(try parse(out).get(nodeType: NodeType(string: "A"), attribute: Attributes.Node.totalOutDegreeMin) == 1)
    }

    /// `vglKey` lowercases, and a hand-written notation uses the camelCase spelling
    /// the docs show. Both have to land on the same attribute.
    @Test("Bound names are matched case-insensitively")
    func boundNamesAreCaseInsensitive() throws {
        let graph = try parse(
            """
            vnotation Bounded {
                node type: A [nodeStyle: bareText, color: "#336699"]
                edge type: aToA  from: A  to: A [outdegreemax: 3]
            }
            vgraph t: Bounded "T" {
                node a1: A "One";
            }
            """)

        #expect(try graph.get(edgeType: EdgeType.Id(rawValue: "aToA"), attribute: Attributes.Edge.outDegreeMax) == 3)
    }

    /// A bound may be the *only* thing an `extends` notation changes about an
    /// inherited type. Both `reconstruct*TypeSpec` functions used to decide
    /// "nothing differs, skip this type" before the bounds were considered, which
    /// dropped exactly this declaration on export.
    @Test("A bound is emitted when it is the only difference from the base")
    func boundAloneSurvivesOverride() throws {
        let source = """
            vnotation BoundedCM extends ConceptMap {
                edge type: concept_to_relation  from: Concept  to: Relation [samePairMax: 1]
            }
            vgraph t: BoundedCM "T" {
                node c1: Concept "Dog";
                node r1: Relation "likes";
                edge c1 -> r1;
            }
            """
        let out = try roundTrip(source)
        #expect(out.contains("samePairMax: 1"))

        let reparsed = try parse(out)
        #expect(
            try reparsed.get(
                edgeType: EdgeType.Id(rawValue: "concept_to_relation"),
                attribute: Attributes.Edge.samePairMax) == 1)
    }

    /// The check has to see what the notation declared, or the whole path is inert.
    @Test("A violated bound is reported by the quality check")
    func violatedBoundIsReported() throws {
        let graph = try parse(
            """
            vnotation Bounded {
                node type: Question [nodeStyle: bareText, color: "#336699"]
                node type: Answer [nodeStyle: bareText, color: "#669933"]
                edge type: answeredBy  from: Question  to: Answer [outDegreeMin: 1]
            }
            vgraph t: Bounded "T" {
                node q1: Question "Unanswered?";
            }
            """)

        let messages = GenericQualityChecks.brokenBounds(graph: graph)
        #expect(messages.count == 1)
        #expect(messages.first?.severity == .warning)
        #expect(messages.first?.target == .node("q1"))
    }

    /// Gained pairs are never written down (ADR-0032), so a bound on a type that
    /// gains them exports as it would without them.
    @Test("A bound on a type that gains pairs round-trips unchanged")
    func boundOnATypeWithGainedPairsRoundTrips() throws {
        let source = """
            vnotation Arch {
                node type: Person [nodeStyle: bareText, color: "#336699"]
                node type: System [nodeStyle: bareText, color: "#669933", detailedBy: (Container)]
                node type: Container [nodeStyle: bareText, color: "#996633"]
                edge type: uses  from: Person  to: System [inDegreeMax: 1, samePairMax: 1]
            }
            vgraph t: Arch "T" {
                node p: Person "Customer";
                group ibs: System "Internet Banking" {
                    node web: Container "Web App";
                };
                edge p -> web;
            }
            """
        let once = try roundTrip(source)

        #expect(once.contains("edge type: uses  from: Person  to: System [inDegreeMax: 1, samePairMax: 1]"))
        #expect(!once.contains("to: Container ["))
        #expect(try roundTrip(once) == once)
        let usesFromReparse = try parse(once).get(edgeType: EdgeType.Id(rawValue: "uses"), attribute: Attributes.Edge.inDegreeMax)
        #expect(usesFromReparse == 1)
    }

    // MARK: - Former names (ADR-0011)

    private func notation(edgeAttrs: String = "", nodeAttrs: String = "") -> String {
        let edgeList = edgeAttrs.isEmpty ? "" : " [\(edgeAttrs)]"
        return """
            vnotation Bounded {
                node type: A [nodeStyle: bareText, color: "#336699"\(nodeAttrs)]
                edge type: aToA  from: A  to: A\(edgeList)
            }
            vgraph t: Bounded "T" {
                node a1: A "One";
            }
            """
    }

    @Test("Every former bound name still parses, onto the renamed bound")
    func formerNamesParse() throws {
        let graph = try parse(
            notation(
                edgeAttrs: "perSourceMin: 1, perSourceMax: 2, perTargetMin: 3, perTargetMax: 4",
                nodeAttrs: ", totalOutMin: 5, totalOutMax: 6, totalInMin: 7, totalInMax: 8"))
        let edge = EdgeType.Id(rawValue: "aToA")
        let node = NodeType(string: "A")

        #expect(try graph.get(edgeType: edge, attribute: Attributes.Edge.outDegreeMin) == 1)
        #expect(try graph.get(edgeType: edge, attribute: Attributes.Edge.outDegreeMax) == 2)
        #expect(try graph.get(edgeType: edge, attribute: Attributes.Edge.inDegreeMin) == 3)
        #expect(try graph.get(edgeType: edge, attribute: Attributes.Edge.inDegreeMax) == 4)
        #expect(try graph.get(nodeType: node, attribute: Attributes.Node.totalOutDegreeMin) == 5)
        #expect(try graph.get(nodeType: node, attribute: Attributes.Node.totalOutDegreeMax) == 6)
        #expect(try graph.get(nodeType: node, attribute: Attributes.Node.totalInDegreeMin) == 7)
        #expect(try graph.get(nodeType: node, attribute: Attributes.Node.totalInDegreeMax) == 8)
    }

    /// The migration: nothing rewrites a document, so saving it is what does.
    @Test("A former name is exported under its new name only")
    func formerNamesExportAsNew() throws {
        let out = try roundTrip(notation(edgeAttrs: "perSourceMin: 1", nodeAttrs: ", totalInMax: 2"))

        #expect(out.contains("outDegreeMin: 1"))
        #expect(out.contains("totalInDegreeMax: 2"))
        #expect(!out.contains("perSourceMin"))
        #expect(!out.contains("totalInMax"))
    }

    @Test("Former names are matched case-insensitively too")
    func formerNamesAreCaseInsensitive() throws {
        let graph = try parse(notation(edgeAttrs: "persourcemax: 3"))
        #expect(try graph.get(edgeType: EdgeType.Id(rawValue: "aToA"), attribute: Attributes.Edge.outDegreeMax) == 3)
    }

    /// ADR-0011: one bound written twice contradicts itself, even with equal values.
    @Test(
        "Giving one bound under its former and its new name is a parse error",
        arguments: [
            (edgeAttrs: "perSourceMin: 1, outDegreeMin: 2", nodeAttrs: ""),
            (edgeAttrs: "perSourceMin: 1, outDegreeMin: 1", nodeAttrs: ""),
            (edgeAttrs: "PERTARGETMAX: 1, inDegreeMax: 2", nodeAttrs: ""),
            (edgeAttrs: "", nodeAttrs: ", totalOutMin: 1, totalOutDegreeMin: 1"),
        ])
    func bothNamesAreAnError(edgeAttrs: String, nodeAttrs: String) {
        #expect(throws: VError.self) {
            try parse(notation(edgeAttrs: edgeAttrs, nodeAttrs: nodeAttrs))
        }
    }

    @Test("The error names the bound and both spellings, so the fix is obvious")
    func bothNamesErrorMessage() {
        #expect(
            throws: VError.parsingError(
                "'aToA' gives outDegreeMin twice, as outDegreeMin and perSourceMin — keep only outDegreeMin")
        ) {
            try parse(notation(edgeAttrs: "perSourceMin: 1, outDegreeMin: 2"))
        }
    }
}
