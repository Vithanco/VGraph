import Testing

@testable import VGLanguage
@testable import VGraph

@Suite
struct BBSNotationFillTests {

    private static let source = """
        vgraph g: BBS "G" {
            node obj1: InvestmentObjective "O1";
            node obj2: InvestmentObjective "O2";
            node ben1: Benefit "B1";
            node ben2: Benefit "B2";
            node chg1: BusinessChange "C1";
            node enb1: Enabler "E1";

            edge ben1 -> obj1: requires_benefit;
            edge chg1 -> ben1: requires_business_change;
            edge enb1 -> chg1: requires_enabler;
            edge obj1 -> obj2: objective_requires_objective;
            edge ben1 -> ben2: benefit_requires_benefit;
        }
        """

    private func parsed() throws -> VGraph {
        try VGraphParser(logger: NoOpLogger()).parse(source: Self.source)
    }

    /// Light-mode hex only: a style stored as an attribute string comes back as a
    /// `literal` token with alpha, so the id and the exact spelling do not survive.
    @Test(arguments: [
        ("obj1", Notations.Bbs.NodeTypes.investmentObjective, "#e8f0ff"),
        ("ben1", Notations.Bbs.NodeTypes.benefit, "#ebfdf2"),
        ("chg1", Notations.Bbs.NodeTypes.businessChange, "#fff4e5"),
        ("enb1", Notations.Bbs.NodeTypes.enabler, "#f0ebff"),
    ])
    func eachNodeTypeWearsItsOwnFill(node: String, type: NodeType, fill: String) throws {
        let graph = try parsed()
        #expect(try graph.nodeType(for: Node(rawValue: node)) == type)
        let background = graph.effectiveNodeLayout(for: type)?.backgroundFill
            .map { String($0.lightHex.lowercased().prefix(7)) }
        #expect(background == fill)
    }

    @Test(arguments: [
        ("ben1", "obj1", "requires_benefit"),
        ("chg1", "ben1", "requires_business_change"),
        ("enb1", "chg1", "requires_enabler"),
        ("obj1", "obj2", "objective_requires_objective"),
        ("ben1", "ben2", "benefit_requires_benefit"),
    ])
    func theEdgeIdsUsersWriteResolveToTheirTypes(from: String, to: String, id: String) throws {
        let graph = try parsed()
        let edge = try #require(graph.edges.first { $0.from == Node(rawValue: from) && $0.to == Node(rawValue: to) })
        #expect(try graph.edgeType(for: edge.id).id.id == id)
    }
}
