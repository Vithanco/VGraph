import TestSupport
import Testing

@testable import App
@testable import VGLanguage
@testable import VGraph

@Suite
struct BBSNotationTests {

    // MARK: - Notation Setup Tests

    @Test func testBBSNotationHasAllNodeTypes() throws {
        var graph = VGraph()
        graph = try Notations.Bbs.addNotation(addTo: graph)

        #expect(graph.has(nodeType: Notations.Bbs.NodeTypes.investmentObjective))
        #expect(graph.has(nodeType: Notations.Bbs.NodeTypes.benefit))
        #expect(graph.has(nodeType: Notations.Bbs.NodeTypes.businessChange))
        #expect(graph.has(nodeType: Notations.Bbs.NodeTypes.enabler))
    }

    @Test func testBBSNotationHasAllEdgeTypes() throws {
        var graph = VGraph()
        graph = try Notations.Bbs.addNotation(addTo: graph)

        // Cross-type edges
        #expect(graph.has(edgeType: Notations.Bbs.EdgeTypes.investmentObjectiveToBenefit.id))
        #expect(graph.has(edgeType: Notations.Bbs.EdgeTypes.benefitToBusinessChange.id))
        #expect(graph.has(edgeType: Notations.Bbs.EdgeTypes.businessChangeToEnabler.id))

        // Same-type edges
        #expect(graph.has(edgeType: Notations.Bbs.EdgeTypes.investmentObjectiveToInvestmentObjective.id))
        #expect(graph.has(edgeType: Notations.Bbs.EdgeTypes.benefitToBenefit.id))
        #expect(graph.has(edgeType: Notations.Bbs.EdgeTypes.businessChangeToBusinessChange.id))
        #expect(graph.has(edgeType: Notations.Bbs.EdgeTypes.enablerToEnabler.id))
    }

    @Test func testBBSNotationHasStyles() throws {
        var graph = VGraph()
        graph = try Notations.Bbs.addNotation(addTo: graph)

        let objectiveStyle: NodeStyleLayout = try graph.get(
            nodeType: Notations.Bbs.NodeTypes.investmentObjective,
            attribute: Attributes.Node.style
        )
        let benefitStyle: NodeStyleLayout = try graph.get(
            nodeType: Notations.Bbs.NodeTypes.benefit,
            attribute: Attributes.Node.style
        )
        let businessChangeStyle: NodeStyleLayout = try graph.get(
            nodeType: Notations.Bbs.NodeTypes.businessChange,
            attribute: Attributes.Node.style
        )
        let enablerStyle: NodeStyleLayout = try graph.get(
            nodeType: Notations.Bbs.NodeTypes.enabler,
            attribute: Attributes.Node.style
        )

        #expect(!objectiveStyle.asString.isEmpty)
        #expect(!benefitStyle.asString.isEmpty)
        #expect(!businessChangeStyle.asString.isEmpty)
        #expect(!enablerStyle.asString.isEmpty)
    }

    // MARK: - Example BBS Graph Test

    @Test func testExampleBBSGraph() throws {
        var graph = VGraph()
        graph = try Notations.Bbs.addNotation(addTo: graph)

        // Investment Objective
        let objective1 = Node(string: "obj1")
        graph = try graph.add(node: objective1, type: Notations.Bbs.NodeTypes.investmentObjective)
        graph = try graph.set(
            node: objective1,
            attribute: Attributes.Node.label.attribute("Increase Customer Satisfaction by 25%")
        )

        // Benefits
        let benefit1 = Node(string: "ben1")
        graph = try graph.add(node: benefit1, type: Notations.Bbs.NodeTypes.benefit)
        graph = try graph.set(
            node: benefit1,
            attribute: Attributes.Node.label.attribute("Faster Response Times")
        )

        let benefit2 = Node(string: "ben2")
        graph = try graph.add(node: benefit2, type: Notations.Bbs.NodeTypes.benefit)
        graph = try graph.set(
            node: benefit2,
            attribute: Attributes.Node.label.attribute("Improved Service Quality")
        )

        let benefit3 = Node(string: "ben3")
        graph = try graph.add(node: benefit3, type: Notations.Bbs.NodeTypes.benefit)
        graph = try graph.set(
            node: benefit3,
            attribute: Attributes.Node.label.attribute("24/7 Support Availability")
        )

        // Business Changes
        let change1 = Node(string: "chg1")
        graph = try graph.add(node: change1, type: Notations.Bbs.NodeTypes.businessChange)
        graph = try graph.set(
            node: change1,
            attribute: Attributes.Node.label.attribute("Automated Ticket Routing")
        )

        let change2 = Node(string: "chg2")
        graph = try graph.add(node: change2, type: Notations.Bbs.NodeTypes.businessChange)
        graph = try graph.set(
            node: change2,
            attribute: Attributes.Node.label.attribute("Self-Service Portal")
        )

        let change3 = Node(string: "chg3")
        graph = try graph.add(node: change3, type: Notations.Bbs.NodeTypes.businessChange)
        graph = try graph.set(
            node: change3,
            attribute: Attributes.Node.label.attribute("Staff Training Program")
        )

        let change4 = Node(string: "chg4")
        graph = try graph.add(node: change4, type: Notations.Bbs.NodeTypes.businessChange)
        graph = try graph.set(
            node: change4,
            attribute: Attributes.Node.label.attribute("24/7 Shift Coverage")
        )

        // Enablers
        let enabler1 = Node(string: "enb1")
        graph = try graph.add(node: enabler1, type: Notations.Bbs.NodeTypes.enabler)
        graph = try graph.set(
            node: enabler1,
            attribute: Attributes.Node.label.attribute("AI-Powered Ticketing System")
        )

        let enabler2 = Node(string: "enb2")
        graph = try graph.add(node: enabler2, type: Notations.Bbs.NodeTypes.enabler)
        graph = try graph.set(
            node: enabler2,
            attribute: Attributes.Node.label.attribute("Customer Portal Platform")
        )

        let enabler3 = Node(string: "enb3")
        graph = try graph.add(node: enabler3, type: Notations.Bbs.NodeTypes.enabler)
        graph = try graph.set(
            node: enabler3,
            attribute: Attributes.Node.label.attribute("Training Materials & LMS")
        )

        let enabler4 = Node(string: "enb4")
        graph = try graph.add(node: enabler4, type: Notations.Bbs.NodeTypes.enabler)
        graph = try graph.set(
            node: enabler4,
            attribute: Attributes.Node.label.attribute("Staffing & Scheduling System")
        )

        let edge1 = Edge(id: "e1", from: benefit1, to: objective1)
        graph = try graph.add(edge: edge1, edgeType: Notations.Bbs.EdgeTypes.investmentObjectiveToBenefit)

        let edge2 = Edge(id: "e2", from: benefit2, to: objective1)
        graph = try graph.add(edge: edge2, edgeType: Notations.Bbs.EdgeTypes.investmentObjectiveToBenefit)

        let edge3 = Edge(id: "e3", from: benefit3, to: objective1)
        graph = try graph.add(edge: edge3, edgeType: Notations.Bbs.EdgeTypes.investmentObjectiveToBenefit)

        // Business Changes to Benefits
        let edge4 = Edge(id: "e4", from: change1, to: benefit1)
        graph = try graph.add(edge: edge4, edgeType: Notations.Bbs.EdgeTypes.benefitToBusinessChange)

        let edge5 = Edge(id: "e5", from: change2, to: benefit2)
        graph = try graph.add(edge: edge5, edgeType: Notations.Bbs.EdgeTypes.benefitToBusinessChange)

        let edge6 = Edge(id: "e6", from: change3, to: benefit2)
        graph = try graph.add(edge: edge6, edgeType: Notations.Bbs.EdgeTypes.benefitToBusinessChange)

        let edge7 = Edge(id: "e7", from: change4, to: benefit3)
        graph = try graph.add(edge: edge7, edgeType: Notations.Bbs.EdgeTypes.benefitToBusinessChange)

        // Enablers to Business Changes
        let edge8 = Edge(id: "e8", from: enabler1, to: change1)
        graph = try graph.add(edge: edge8, edgeType: Notations.Bbs.EdgeTypes.businessChangeToEnabler)

        let edge9 = Edge(id: "e9", from: enabler2, to: change2)
        graph = try graph.add(edge: edge9, edgeType: Notations.Bbs.EdgeTypes.businessChangeToEnabler)

        let edge10 = Edge(id: "e10", from: enabler3, to: change3)
        graph = try graph.add(edge: edge10, edgeType: Notations.Bbs.EdgeTypes.businessChangeToEnabler)

        let edge11 = Edge(id: "e11", from: enabler4, to: change4)
        graph = try graph.add(edge: edge11, edgeType: Notations.Bbs.EdgeTypes.businessChangeToEnabler)

        let edge12 = Edge(id: "e12", from: change1, to: change2)
        graph = try graph.add(edge: edge12, edgeType: Notations.Bbs.EdgeTypes.businessChangeToBusinessChange)

        let edge13 = Edge(id: "e13", from: enabler1, to: enabler2)
        graph = try graph.add(edge: edge13, edgeType: Notations.Bbs.EdgeTypes.enablerToEnabler)

        #expect(graph.nodes.count == 12)  // 1 objective + 3 benefits + 4 changes + 4 enablers
        #expect(graph.edges.count == 13)

        let label1: String = try graph.get(node: objective1, attribute: Attributes.Node.label)
        #expect(label1 == "Increase Customer Satisfaction by 25%")

        let label2: String = try graph.get(node: benefit1, attribute: Attributes.Node.label)
        #expect(label2 == "Faster Response Times")

        let label3: String = try graph.get(node: change1, attribute: Attributes.Node.label)
        #expect(label3 == "Automated Ticket Routing")

        let label4: String = try graph.get(node: enabler1, attribute: Attributes.Node.label)
        #expect(label4 == "AI-Powered Ticketing System")
    }

    @Test func testSameTypeEdgesWork() throws {
        var graph = VGraph()
        graph = try Notations.Bbs.addNotation(addTo: graph)

        let enabler1 = Node(string: "enb1")
        graph = try graph.add(node: enabler1, type: Notations.Bbs.NodeTypes.enabler)
        graph = try graph.set(node: enabler1, attribute: Attributes.Node.label.attribute("Database"))

        let enabler2 = Node(string: "enb2")
        graph = try graph.add(node: enabler2, type: Notations.Bbs.NodeTypes.enabler)
        graph = try graph.set(node: enabler2, attribute: Attributes.Node.label.attribute("API Layer"))

        let edge = Edge(id: "e1", from: enabler2, to: enabler1)
        graph = try graph.add(edge: edge, edgeType: Notations.Bbs.EdgeTypes.enablerToEnabler)

        #expect(graph.nodes.count == 2)
        #expect(graph.edges.count == 1)

        let retrievedEdge = graph.get(edge: edge.id)
        #expect(retrievedEdge == edge)
    }

    // MARK: - Parser Tests

    @Test func testBBSGraphFromParser() throws {
        let bbsInput = """
            vgraph customerSatisfaction: BBS "Customer Satisfaction Initiative" {
                node obj1: InvestmentObjective "Increase Customer Satisfaction by 25%";
                node ben1: Benefit "Faster Response Times";
                node ben2: Benefit "Improved Service Quality";
                node ben3: Benefit "24/7 Support Availability";
                node chg1: BusinessChange "Automated Ticket Routing";
                node chg2: BusinessChange "Self-Service Portal";
                node chg3: BusinessChange "Staff Training Program";
                node chg4: BusinessChange "24/7 Shift Coverage";
                node enb1: Enabler "AI-Powered Ticketing System";
                node enb2: Enabler "Customer Portal Platform";
                node enb3: Enabler "Training Materials & LMS";
                node enb4: Enabler "Staffing & Scheduling System";

                edge ben1 -> obj1: requires_benefit;
                edge ben2 -> obj1: requires_benefit;
                edge ben3 -> obj1: requires_benefit;
                edge chg1 -> ben1: requires_business_change;
                edge chg2 -> ben2: requires_business_change;
                edge chg3 -> ben2: requires_business_change;
                edge chg4 -> ben3: requires_business_change;
                edge enb1 -> chg1: requires_enabler;
                edge enb2 -> chg2: requires_enabler;
                edge enb3 -> chg3: requires_enabler;
                edge enb4 -> chg4: requires_enabler;
                edge chg1 -> chg2: change_requires_change;
                edge enb1 -> enb2: enabler_requires_enabler;
            }
            """

        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: bbsInput)

        let id: String = try graph.get(graphAttribute: Attributes.Group.Id)
        #expect(id == "customerSatisfaction")
        let label: String = try graph.get(graphAttribute: Attributes.Group.label)
        #expect(label == "Customer Satisfaction Initiative")

        #expect(graph.nodes.count == 12)  // 1 objective + 3 benefits + 4 changes + 4 enablers
        #expect(graph.edges.count == 13)

        let obj1 = Node(string: "obj1")
        let ben1 = Node(string: "ben1")
        let chg1 = Node(string: "chg1")
        let enb1 = Node(string: "enb1")

        #expect(graph.has(node: obj1))
        #expect(graph.has(node: ben1))
        #expect(graph.has(node: chg1))
        #expect(graph.has(node: enb1))

        #expect((try graph.nodeType(for: obj1)) == Notations.Bbs.NodeTypes.investmentObjective)
        #expect((try graph.nodeType(for: ben1)) == Notations.Bbs.NodeTypes.benefit)
        #expect((try graph.nodeType(for: chg1)) == Notations.Bbs.NodeTypes.businessChange)
        #expect((try graph.nodeType(for: enb1)) == Notations.Bbs.NodeTypes.enabler)

        let obj1Label: String = try graph.get(node: obj1, attribute: Attributes.Node.label)
        #expect(obj1Label == "Increase Customer Satisfaction by 25%")

        let ben1Label: String = try graph.get(node: ben1, attribute: Attributes.Node.label)
        #expect(ben1Label == "Faster Response Times")

        let chg1Label: String = try graph.get(node: chg1, attribute: Attributes.Node.label)
        #expect(chg1Label == "Automated Ticket Routing")

        let enb1Label: String = try graph.get(node: enb1, attribute: Attributes.Node.label)
        #expect(enb1Label == "AI-Powered Ticketing System")

        #expect(fill(of: Notations.Bbs.NodeTypes.investmentObjective, in: graph) == Notations.Bbs.ioFill.lightHex.lowercased())
        #expect(fill(of: Notations.Bbs.NodeTypes.benefit, in: graph) == Notations.Bbs.benFill.lightHex.lowercased())
        #expect(fill(of: Notations.Bbs.NodeTypes.businessChange, in: graph) == Notations.Bbs.bcFill.lightHex.lowercased())
        #expect(fill(of: Notations.Bbs.NodeTypes.enabler, in: graph) == Notations.Bbs.enFill.lightHex.lowercased())

        let edges = graph.edges

        // Find specific edges and verify their types (edges now go from Enabler -> BC -> Benefit -> Obj)
        let benToObj = edges.first { $0.from == ben1 && $0.to == obj1 }
        #expect(benToObj != nil)
        #expect((try graph.edgeType(for: benToObj!.id)) == Notations.Bbs.EdgeTypes.investmentObjectiveToBenefit)

        let chgToBen = edges.first { $0.from == chg1 && $0.to == ben1 }
        #expect(chgToBen != nil)
        #expect((try graph.edgeType(for: chgToBen!.id)) == Notations.Bbs.EdgeTypes.benefitToBusinessChange)

        let enbToChg = edges.first { $0.from == enb1 && $0.to == chg1 }
        #expect(enbToChg != nil)
        #expect((try graph.edgeType(for: enbToChg!.id)) == Notations.Bbs.EdgeTypes.businessChangeToEnabler)

        let chg2 = Node(string: "chg2")
        let chgToChg = edges.first { $0.from == chg1 && $0.to == chg2 }
        #expect(chgToChg != nil)
        #expect((try graph.edgeType(for: chgToChg!.id)) == Notations.Bbs.EdgeTypes.businessChangeToBusinessChange)

        let enb2 = Node(string: "enb2")
        let enbToEnb = edges.first { $0.from == enb1 && $0.to == enb2 }
        #expect(enbToEnb != nil)
        #expect((try graph.edgeType(for: enbToEnb!.id)) == Notations.Bbs.EdgeTypes.enablerToEnabler)
    }

    @Test func testBBSColorConstants() {
        #expect(!Notations.Bbs.ioFill.hexString.isEmpty)
        #expect(!Notations.Bbs.ioBorder.hexString.isEmpty)
        #expect(!Notations.Bbs.ioText.hexString.isEmpty)
        #expect(!Notations.Bbs.benFill.hexString.isEmpty)
        #expect(!Notations.Bbs.benBorder.hexString.isEmpty)
        #expect(!Notations.Bbs.benText.hexString.isEmpty)
        #expect(!Notations.Bbs.bcFill.hexString.isEmpty)
        #expect(!Notations.Bbs.bcBorder.hexString.isEmpty)
        #expect(!Notations.Bbs.bcText.hexString.isEmpty)
        #expect(!Notations.Bbs.enFill.hexString.isEmpty)
        #expect(!Notations.Bbs.enBorder.hexString.isEmpty)
        #expect(!Notations.Bbs.enText.hexString.isEmpty)

        #expect(Notations.Bbs.ioFill.hexString == "#e8f0ff")
        #expect(Notations.Bbs.ioBorder.hexString == "#2858d0")
        #expect(Notations.Bbs.ioText.hexString == "#0a2878")
        #expect(Notations.Bbs.benFill.hexString == "#ebfdf2")
        #expect(Notations.Bbs.benBorder.hexString == "#209858")
        #expect(Notations.Bbs.benText.hexString == "#0a5028")
        #expect(Notations.Bbs.bcFill.hexString == "#fff4e5")
        #expect(Notations.Bbs.bcBorder.hexString == "#c87820")
        #expect(Notations.Bbs.bcText.hexString == "#6a3c08")
        #expect(Notations.Bbs.enFill.hexString == "#f0ebff")
        #expect(Notations.Bbs.enBorder.hexString == "#7038d0")
        #expect(Notations.Bbs.enText.hexString == "#3a1878")
    }

    @Test func testBBSLayoutDirectionIsLeftToRight() throws {
        var graph = VGraph()
        graph = try Notations.Bbs.addNotation(addTo: graph)

        let layoutDirectionString: String = try graph.get(
            graphAttribute: Attributes.Group.layoutDirection
        )
        let layoutDirection = try LayoutDirection.fromString(layoutDirectionString)
        #expect(layoutDirection == .leftToRight)
    }

    @Test func testBBSGraphFromParser2() throws {
        let bbsInput = """
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
        let parser = VGraphParser(logger: NoOpLogger())
        let _ = try parser.parse(source: bbsInput)
    }

    /// Light-mode hex only: a style stored as an attribute string comes back as a
    /// `literal` token with alpha, so the id and the exact spelling do not survive.
    private func fill(of nodeType: NodeType, in graph: VGraph) -> String? {
        graph.effectiveNodeLayout(for: nodeType)?.backgroundFill
            .map { String($0.lightHex.lowercased().prefix(7)) }
    }

}
