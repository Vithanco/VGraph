import Testing

@testable import VGLanguage
@testable import VGraph

/// Untyped edges: each BBS node-type pair has exactly one edge type, so the
/// parser infers it. One row per pair; a second edge on a pair resolves the same way. `BBSNotationFillTests` owns the explicitly typed spelling.
@Suite
struct BBSTest {

    private static let source = """
        vgraph project: BBS "Sample Project" {
            node obj1: InvestmentObjective "Increase Revenue";
            node ben1: Benefit "Faster Customer Onboarding";
            node ben2: Benefit "Improved Customer Satisfaction";
            node bc1: BusinessChange "Automated Registration Process";
            node bc2: BusinessChange "Self-Service Portal";
            node en1: Enabler "Implement Online Forms";
            node en2: Enabler "Deploy Customer Portal";
            node en3: Enabler "Train Support Team";

            edge ben1 -> obj1;
            edge ben2 -> obj1;
            edge bc1 -> ben1;
            edge bc2 -> ben2;
            edge en1 -> bc1;
            edge en2 -> bc2;
            edge en3 -> bc2;
        }
        """

    @Test(arguments: [
        ("ben1", "obj1", "requires_benefit"),
        ("bc1", "ben1", "requires_business_change"),
        ("en1", "bc1", "requires_enabler"),
    ])
    func anUntypedEdgeTakesTheOnlyTypeItsEndsAllow(from: String, to: String, id: String) throws {
        let graph = try VGraphParser(logger: NoOpLogger()).parse(source: Self.source)
        let edge = try #require(graph.edges.first { $0.from == Node(rawValue: from) && $0.to == Node(rawValue: to) })
        #expect(try graph.edgeType(for: edge.id).id.id == id)
    }
}
