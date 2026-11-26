// Each check's rule is published as written, so each check is shown breaking on
// a document made to break it: a rule that no longer matches its check fails
// here rather than on the website.

import Testing

@testable import VGLanguage
@testable import VGraph

private func parse(_ source: String) throws -> VGraph {
    try VGraphParser(logger: NoOpLogger()).parse(source: source)
}

/// Every stock linked to every other: more loops than can be marked.
private let denseLoops: String = {
    let names = (0..<12).map { "s\($0)" }
    let nodes = names.map { "node \($0): Stock \"\($0)\";" }
    let edges = names.flatMap { a in names.filter { $0 != a }.map { "edge \(a) -> \($0): same;" } }
    return "vgraph cld: CLD \"Dense\" {\n" + (nodes + edges).joined(separator: "\n") + "\n}"
}()

private func conceptMap(_ body: String) -> String {
    "vgraph cm: ConceptMap \"Map\" {\n\(body)\n}"
}

/// Five concepts, so only the rule under test is broken.
private let fiveConcepts = """
    node a: Concept "A"; node b: Concept "B"; node c: Concept "C"; node d: Concept "D"; node e: Concept "E";
    """

/// Keyed by registry id and check name.
private let notationSnippets: [String: String] = [
    "IBIS/treeStructure": """
    vgraph g: IBIS "Tree" {
        node q1: Question "Why?"; node q2: Question "How?"; node a: Answer "Because";
        edge q1 -> a; edge q2 -> a;
    }
    """,
    "IBIS/unansweredQuestions": #"vgraph g: IBIS "Open" { node q: Question "Why?"; }"#,
    "CLD/unmarkedLoops": denseLoops,
    "Arithmetic/divisionByZero": """
    vgraph g: Arithmetic "Zero" {
        node eight: Number "8"; node zero: Number "0"; node div: Divide; node eq: Equals "1";
        edge eight -> div: divide_first_operand; edge zero -> div: divide_second_operand;
        edge div -> eq: divide_result;
    }
    """,
    "C4/unlabeledRelationship": """
    vgraph g: C4 "Unlabeled" {
        node user: Person "User"; node sys: SoftwareSystem "System";
        edge user -> sys;
    }
    """,
    "GoalTree/exactlyOne": #"vgraph g: GoalTree "Two" { node g1: Goal "One"; node g2: Goal "Two"; }"#,
    "GoalTree/csfCount": #"vgraph g: GoalTree "Few" { node g: Goal "Goal"; node c: CriticalSuccessFactor "Only"; edge c -> g; }"#,
    "ConceptMap/conceptCount": conceptMap(
        #"node a: Concept "A"; node b: Concept "B"; node r: Relation "likes"; edge a -> r; edge r -> b;"#),
    "ConceptMap/labelLength": conceptMap(
        fiveConcepts + #" node long: Concept "One two three four"; node r: Relation "likes"; edge a -> r; edge r -> long;"#),
    "ConceptMap/vagueRelations": conceptMap(
        fiveConcepts + #" node r: Relation "is related to"; edge a -> r; edge r -> b;"#),
    "ConceptMap/disconnectedClusters": conceptMap(
        fiveConcepts + #" node r1: Relation "likes"; node r2: Relation "eats"; edge a -> r1; edge r1 -> b; edge c -> r2; edge r2 -> d;"#),
    "ConceptMap/bothDirections": conceptMap(
        fiveConcepts + #" node r1: Relation "feeds"; node r2: Relation "is fed by"; edge a -> r1; edge r1 -> b; edge b -> r2; edge r2 -> a;"#),
    "ConceptMap/repeatedRelations": conceptMap(
        fiveConcepts + #" node r1: Relation "has"; node r2: Relation "has"; edge a -> r1; edge r1 -> c; edge b -> r2; edge r2 -> c;"#),
    "ConceptMap/manyToMany": conceptMap(
        fiveConcepts + #" node r: Relation "feeds"; edge a -> r; edge b -> r; edge r -> c; edge r -> d;"#),
    "ConceptMap/incompleteRelations": conceptMap(fiveConcepts + #" node r: Relation "likes"; edge a -> r;"#),
]

/// Keyed by registry name; the spec gives a parameterised check its numbers.
private let namedSnippets: [String: (spec: String, source: String)] = [
    "treeStructure": ("treeStructure", notationSnippets["IBIS/treeStructure"] ?? ""),
    "noParallelEdges": (
        "noParallelEdges",
        """
        vgraph g: CLD "Twice" {
            node a: Stock "A"; node b: Stock "B";
            edge a -> b: same; edge a -> b: opposite;
        }
        """
    ),
    "exactlyOne": ("exactlyOne(Goal)", notationSnippets["GoalTree/exactlyOne"] ?? ""),
    "nodeCountRange": ("nodeCountRange(Question, 2, 5)", notationSnippets["IBIS/unansweredQuestions"] ?? ""),
    "labelLength": ("labelLength(2)", #"vgraph g: IBIS "Long" { node q: Question "Why is this so long"; }"#),
]

@Suite
struct QualityCheckTripsTest {

    @Test
    func everyNotationCheckHasADocumentThatBreaksIt() {
        let checks = NotationRegistry.entries.flatMap { id, entry in entry.qualityChecks.map { "\(id)/\($0.name)" } }
        #expect(Set(checks) == Set(notationSnippets.keys))
    }

    @Test
    func everyCheckAVnotationCanNameHasADocumentThatBreaksIt() {
        let names = QualityCheckRegistry.names.filter { !GenericQualityChecks.runsAlways(QualityCheckSpec(name: $0)) }
        #expect(Set(names) == Set(namedSnippets.keys))
    }

    @Test(arguments: notationSnippets.keys.sorted())
    func aNotationCheckFiresOnItsDocument(key: String) throws {
        let parts = key.split(separator: "/").map(String.init)
        let entry = try #require(NotationRegistry.entry(for: parts[0]))
        let check = try #require(entry.qualityChecks.first { $0.name == parts[1] })
        let graph = try parse(try #require(notationSnippets[key]))
        #expect(!check(graph).isEmpty, "\(key) did not fire: \(check.rule)")
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
