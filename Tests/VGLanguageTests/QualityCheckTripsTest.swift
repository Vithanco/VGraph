// A check a vnotation can name has no notation of its own to hold a
// [[Counterexample]], so it is shown breaking on a document made to break it here.

import Testing

@testable import VGLanguage
@testable import VGraph

private func parse(_ source: String) throws -> VGraph {
    try VGraphParser(logger: NoOpLogger()).parse(source: source)
}

/// Keyed by registry name; the spec gives a parameterised check its numbers.
private let namedSnippets: [String: (spec: String, source: String)] = [
    "treeStructure": (
        "treeStructure",
        """
        vgraph g: IBIS "Tree" {
            node q1: Question "Why?"; node q2: Question "How?"; node a: Answer "Because";
            edge q1 -> a; edge q2 -> a;
        }
        """
    ),
    "noParallelEdges": (
        "noParallelEdges",
        """
        vgraph g: CLD "Twice" {
            node a: Stock "A"; node b: Stock "B";
            edge a -> b: same; edge a -> b: opposite;
        }
        """
    ),
    "exactlyOne": ("exactlyOne(Goal)", #"vgraph g: GoalTree "Two" { node g1: Goal "One"; node g2: Goal "Two"; }"#),
    "nodeCountRange": ("nodeCountRange(Question, 2, 5)", #"vgraph g: IBIS "Open" { node q: Question "Why?"; }"#),
    "labelLength": ("labelLength(2)", #"vgraph g: IBIS "Long" { node q: Question "Why is this so long"; }"#),
]

@Suite
struct QualityCheckTripsTest {

    @Test
    func everyCheckAVnotationCanNameHasADocumentThatBreaksIt() {
        let names = QualityCheckRegistry.names.filter { !GenericQualityChecks.runsAlways(QualityCheckSpec(name: $0)) }
        #expect(Set(names) == Set(namedSnippets.keys))
    }

    @Test(arguments: namedSnippets.keys.sorted())
    func aNamedCheckFiresOnItsDocument(name: String) throws {
        let row = try #require(namedSnippets[name])
        let check = try QualityCheckRegistry.resolve(QualityCheckSpec.parse(row.spec))
        #expect(!check(try parse(row.source)).isEmpty, "\(name) did not fire: \(check.rule)")
    }

    @Test
    func aVnotationNamingNoChecksIsJudgedByTheNotationItExtends() throws {
        let graph = try parse(
            """
            vnotation Mine extends IBIS {
                node type: Extra [nodeStyle: withCategory, color: "#884499", category: "E"]
            }
            vgraph g: Mine "Open" { node q: Question "Why?"; }
            """)
        let ibis = try #require(NotationRegistry.entry(for: "IBIS"))
        let unanswered = try #require(ibis.qualityChecks.first { $0.name == "unansweredQuestions" })
        let findings = unanswered(graph)
        let reported = Notations.analyzeQuality(graph: graph).messages
        #expect(!findings.isEmpty)
        #expect(findings.allSatisfy { reported.contains($0) })
        #expect(Notations.rules(in: graph).contains(unanswered.rule))
    }
}
