import Foundation
import Testing

@testable import App
@testable import VGLanguage
@testable import VGraph
@testable import VGraphvizLib

/// A complex test graph with 50 explicit nodes (+ 4 unknown node types = 54 total), 70 edges, and 6 groups
/// One group (groupE) is nested 3 levels deep with 2 parent groups
/// Includes graph-level properties: rankdir (layout direction), fontcolor, and labeljust
/// Note: Some edges create unknown node types because they connect incompatible IBIS node types
let complexGraphInput = """
    vgraph complexGraph: IBIS "Complex Test Graph" {
        rankdir: LR;
        fontcolor: darkblue;
        labeljust: l;

        node root1: Question "Root Question 1" [fontsize: 16];
        node root2: Question "Root Question 2" [fontsize: 16];
        node root3: Answer "Root Answer 1" [fontsize: 14];
        node root4: Answer "Root Answer 2" [fontsize: 14];
        node root5: Pro "Root Pro 1" [fontsize: 12];
        node root6: Con "Root Con 1" [fontsize: 12];
        node root7: Question "Root Question 3" [fontsize: 16];
        node root8: Answer "Root Answer 3" [fontsize: 14];
        node root9: Pro "Root Pro 2" [fontsize: 12];
        node root10: Con "Root Con 2" [fontsize: 12];

        group groupA "Research and Analysis" {
            style: filled;
            color: lightblue;

            node a1: Question "Research Direction?" [fontsize: 15];
            node a2: Answer "Conduct user interviews" [fontsize: 13];
            node a3: Answer "Analyze market data" [fontsize: 13];
            node a4: Pro "Direct user feedback" [fontsize: 11];
            node a5: Pro "Statistical validation" [fontsize: 11];
            node a6: Con "Time consuming" [fontsize: 11];
            node a7: Con "Expensive" [fontsize: 11];
            node a8: Question "Data quality?" [fontsize: 14];
            node a9: Answer "Use third-party sources" [fontsize: 13];
            node a10: Pro "Comprehensive coverage" [fontsize: 11];
            node a11: Con "Reliability concerns" [fontsize: 11];
            node a12: Question "Follow-up needed?" [fontsize: 14];
        };

        group groupB "Implementation Strategy" {
            style: filled;
            color: lightgreen;

            node b1: Question "Which architecture?" [fontsize: 15];
            node b2: Answer "Microservices architecture" [fontsize: 13];
            node b3: Answer "Monolithic architecture" [fontsize: 13];
            node b4: Pro "Scalability" [fontsize: 11];
            node b5: Pro "Independent deployment" [fontsize: 11];
            node b6: Con "Operational complexity" [fontsize: 11];
            node b7: Pro "Simpler to start" [fontsize: 11];
            node b8: Con "Scaling limitations" [fontsize: 11];
            node b9: Question "Technology stack?" [fontsize: 14];
            node b10: Answer "Use modern frameworks" [fontsize: 13];
        };

        group groupC "Testing and Quality" {
            style: filled;
            color: lightyellow;

            node c1: Question "Testing strategy?" [fontsize: 15];
            node c2: Answer "Comprehensive test coverage" [fontsize: 13];
            node c3: Pro "Prevents regressions" [fontsize: 11];
            node c4: Con "Slows development" [fontsize: 11];

            group groupD "Automated Testing" {
                style: dashed;
                color: orange;

                node d1: Question "Which test types?" [fontsize: 14];
                node d2: Answer "Unit + Integration + E2E" [fontsize: 12];
                node d3: Pro "Complete coverage" [fontsize: 10];
                node d4: Con "Maintenance overhead" [fontsize: 10];

                group groupE "CI-CD Pipeline" {
                    style: dotted;
                    color: purple;

                    node e1: Question "Which CI platform?" [fontsize: 13];
                    node e2: Answer "GitHub Actions" [fontsize: 12];
                    node e3: Pro "Native integration" [fontsize: 10];
                    node e4: Con "Limited customization" [fontsize: 10];
                };
            };
        };

        group groupF "Deployment" {
            style: filled;
            color: lightcoral;

            node f1: Question "Deployment target?" [fontsize: 15];
            node f2: Answer "Cloud platform" [fontsize: 13];
            node f3: Answer "On-premise servers" [fontsize: 13];
            node f4: Pro "Managed infrastructure" [fontsize: 11];
            node f5: Pro "Global availability" [fontsize: 11];
            node f6: Con "Vendor lock-in" [fontsize: 11];
            node f7: Pro "Full control" [fontsize: 11];
            node f8: Con "Maintenance burden" [fontsize: 11];
            node f9: Question "Scaling approach?" [fontsize: 14];
            node f10: Answer "Auto-scaling groups" [fontsize: 13];
        };

        edge root1 -> root3: answered_by "Initial analysis";
        edge root1 -> root4: answered_by "Alternative approach";
        edge root3 -> root5: supports "Performance benefits";
        edge root3 -> root6: objects_to "Resource concerns";
        edge root2 -> root3: answered_by "Shared solution";
        edge root2 -> root8: answered_by "Different path";
        edge root4 -> root9: supports "Cost effective";
        edge root4 -> root10: objects_to "Quality issues";
        edge root5 -> root7: pro_questions_question "Next steps?";
        edge root6 -> root7: con_questions_question "Risk mitigation?";
        edge root7 -> root8: answered_by "Comprehensive plan";
        edge root8 -> root9: supports "Budget friendly";
        edge root8 -> root10: objects_to "Timeline concerns";
        edge root9 -> root1: pro_questions_question "Validation needed?";
        edge root10 -> root2: con_questions_question "Alternatives?";

        edge a1 -> a2: answered_by;
        edge a1 -> a3: answered_by;
        edge a2 -> a4: supports;
        edge a2 -> a6: objects_to;
        edge a3 -> a5: supports;
        edge a3 -> a7: objects_to;
        edge a4 -> a8: pro_questions_question;
        edge a5 -> a8: pro_questions_question;
        edge a6 -> a12: con_questions_question;
        edge a7 -> a12: con_questions_question;
        edge a8 -> a9: answered_by;
        edge a9 -> a10: supports;
        edge a9 -> a11: objects_to;
        edge a10 -> a12: pro_questions_question;
        edge a11 -> a12: con_questions_question;

        edge b1 -> b2: answered_by;
        edge b1 -> b3: answered_by;
        edge b2 -> b4: supports;
        edge b2 -> b5: supports;
        edge b2 -> b6: objects_to;
        edge b3 -> b7: supports;
        edge b3 -> b8: objects_to;
        edge b4 -> b9: pro_questions_question;
        edge b5 -> b9: pro_questions_question;
        edge b6 -> b9: con_questions_question;
        edge b8 -> b9: con_questions_question;
        edge b9 -> b10: answered_by;

        edge c1 -> c2: answered_by;
        edge c2 -> c3: supports;
        edge c2 -> c4: objects_to;
        edge c3 -> d1: pro_questions_question;
        edge c4 -> d1: con_questions_question;
        edge d1 -> d2: answered_by;
        edge d2 -> d3: supports;
        edge d2 -> d4: objects_to;
        edge d3 -> e1: pro_questions_question;
        edge d4 -> e1: con_questions_question;
        edge e1 -> e2: answered_by;
        edge e2 -> e3: supports;
        edge e2 -> e4: objects_to;
        edge e3 -> c1: pro_questions_question "Improves workflow";
        edge e4 -> c1: con_questions_question "Setup complexity";

        edge f1 -> f2: answered_by;
        edge f1 -> f3: answered_by;
        edge f2 -> f4: supports;
        edge f2 -> f5: supports;
        edge f2 -> f6: objects_to;
        edge f3 -> f7: supports;
        edge f3 -> f8: objects_to;
        edge f4 -> f9: pro_questions_question;
        edge f5 -> f9: pro_questions_question;
        edge f6 -> f9: con_questions_question;
        edge f8 -> f9: con_questions_question;
        edge f9 -> f10: answered_by;
        edge f1 -> root8: answered_by "Determines deployment";
    }
    """

/// A complex Impact Mapping test graph with multiple goals, actors, impacts, and deliverables
/// Tests the full cycle: Goal → Actor → Impact → Deliverable hierarchy
/// Includes groups, nested groups, and graph-level properties
let impactMappingInput = """
    vgraph productLaunch: ImpactMapping "Product Launch Strategy" {
        rankdir: LR;
        fontcolor: darkblue;

        group marketingTeam "Marketing Team" {
            style: filled;
            color: lightblue;

            // Goal 1: Increase Market Share
            node goal1: Goal "Increase market share by 20%" [fontsize: 16];

            node actor1: Actor "Marketing Director" [fontsize: 14];
            node actor2: Actor "Social Media Manager" [fontsize: 14];

            node impact1: Impact "Higher brand awareness" [fontsize: 13];
            node impact2: Impact "Increased engagement" [fontsize: 13];
            node impact3: Impact "More qualified leads" [fontsize: 13];

            node deliv1: Deliverable "Launch campaign" [fontsize: 12];
            node deliv2: Deliverable "Social media content" [fontsize: 12];
            node deliv3: Deliverable "Lead scoring system" [fontsize: 12];
        };

        group productTeam "Product Team" {
            style: filled;
            color: lightgreen;

            // Goal 2: Improve Customer Satisfaction
            node goal2: Goal "Improve customer satisfaction to 95%" [fontsize: 16];

            node actor3: Actor "Product Manager" [fontsize: 14];
            node actor4: Actor "UX Designer" [fontsize: 14];

            node impact4: Impact "Better user experience" [fontsize: 13];
            node impact5: Impact "Faster feature delivery" [fontsize: 13];
            node impact6: Impact "Reduced support tickets" [fontsize: 13];

            node deliv6: Deliverable "User research" [fontsize: 12];
            node deliv7: Deliverable "Prototype testing" [fontsize: 12];
            node deliv8: Deliverable "Feature prioritization" [fontsize: 12];

            group developmentTeam "Development Team" {
                style: dashed;
                color: orange;

                node actor5: Actor "Tech Lead" [fontsize: 14];
                node impact7: Impact "Improved code quality" [fontsize: 13];
                node deliv4: Deliverable "Automated testing" [fontsize: 12];
                node deliv5: Deliverable "Code reviews" [fontsize: 12];
            };
        };

        group operationsTeam "Operations Team" {
            style: filled;
            color: lightyellow;

            // Goal 3: Reduce Costs
            node goal3: Goal "Reduce operational costs by 15%" [fontsize: 16];

            node actor6: Actor "Operations Manager" [fontsize: 14];
            node actor7: Actor "DevOps Engineer" [fontsize: 14];

            node impact8: Impact "Optimized infrastructure" [fontsize: 13];
            node impact9: Impact "Automated processes" [fontsize: 13];

            node deliv9: Deliverable "Cloud migration" [fontsize: 12];
            node deliv10: Deliverable "CI/CD pipeline" [fontsize: 12];
            node deliv11: Deliverable "Monitoring dashboard" [fontsize: 12];
        };

        // Edges: Goal → Actor → Impact → Deliverable
        edge goal1 -> actor1: goal_to_actor "Leads initiative";
        edge goal1 -> actor2: goal_to_actor "Supports campaign";

        edge actor1 -> impact1: actor_to_impact "Drives awareness";
        edge actor1 -> impact3: actor_to_impact "Generates leads";
        edge actor2 -> impact2: actor_to_impact "Boosts engagement";

        edge impact1 -> deliv1: impact_to_deliverable "Via campaign";
        edge impact2 -> deliv2: impact_to_deliverable "Through content";
        edge impact3 -> deliv3: impact_to_deliverable "Using scoring";

        edge goal2 -> actor3: goal_to_actor "Owns product";
        edge goal2 -> actor4: goal_to_actor "Designs UX";
        edge goal2 -> actor5: goal_to_actor "Implements features";

        edge actor3 -> impact5: actor_to_impact "Accelerates delivery";
        edge actor3 -> impact6: actor_to_impact "Reduces issues";
        edge actor4 -> impact4: actor_to_impact "Improves UX";
        edge actor5 -> impact7: actor_to_impact "Ensures quality";

        edge impact4 -> deliv6: impact_to_deliverable "Through research";
        edge impact4 -> deliv7: impact_to_deliverable "Via prototypes";
        edge impact5 -> deliv8: impact_to_deliverable "Using prioritization";
        edge impact7 -> deliv4: impact_to_deliverable "Via testing";
        edge impact7 -> deliv5: impact_to_deliverable "Through reviews";

        edge goal3 -> actor6: goal_to_actor "Manages operations";
        edge goal3 -> actor7: goal_to_actor "Handles infrastructure";

        edge actor6 -> impact8: actor_to_impact "Optimizes resources";
        edge actor6 -> impact9: actor_to_impact "Automates workflows";
        edge actor7 -> impact8: actor_to_impact "Improves infrastructure";
        edge actor7 -> impact9: actor_to_impact "Builds automation";

        edge impact8 -> deliv9: impact_to_deliverable "Through migration";
        edge impact9 -> deliv10: impact_to_deliverable "Via pipeline";
        edge impact9 -> deliv11: impact_to_deliverable "Using dashboard";
    }
    """

// MARK: - Helper Functions

/// Compares two graphs for structural and attribute equality.
/// This includes nodes, edges, groups, their attributes, and graph-level attributes.
func assertGraphsAreEqual(_ g1: VGraph, _ g2: VGraph, sourceLocation: SourceLocation = #_sourceLocation) throws {
    #expect(g1.nodes.count == g2.nodes.count, "Graphs should have same number of nodes", sourceLocation: sourceLocation)

    let g1NodeIds = g1.nodes.map { $0.id.description }
    let g2NodeIds = g2.nodes.map { $0.id.description }
    #expect(g1NodeIds == g2NodeIds, "Node order should be preserved: \(g1NodeIds) vs \(g2NodeIds)", sourceLocation: sourceLocation)

    for node in g1.nodes {
        let attrs1 = try g1.getAttributes(node: node)
        let attrs2 = try g2.getAttributes(node: node)

        #expect(
            attrs1.count == attrs2.count,
            "Node \(node.id) should have same number of attributes: \(attrs1.count) vs \(attrs2.count)",
            sourceLocation: sourceLocation)

        for (key, value1) in attrs1 {
            // Skip itemOrder - we verify order preservation separately
            if key.description == "node.itemOrder" {
                continue
            }

            guard let value2 = attrs2[key] else {
                Issue.record("Node \(node.id) missing attribute \(key) in g2", sourceLocation: sourceLocation)
                continue
            }
            #expect(
                value1 == value2,
                "Node \(node.id) attribute \(key) should match: '\(value1)' vs '\(value2)'",
                sourceLocation: sourceLocation)

            #expect(
                type(of: value1) == type(of: value2),
                "Node \(node.id) attribute \(key) should have same type",
                sourceLocation: sourceLocation)
        }
    }

    #expect(g1.edges.count == g2.edges.count, "Graphs should have same number of edges", sourceLocation: sourceLocation)

    for edge1 in g1.edges {
        guard let edge2 = g2.edges.first(where: { $0.from == edge1.from && $0.to == edge1.to }) else {
            Issue.record("Edge from \(edge1.from) to \(edge1.to) not found in g2", sourceLocation: sourceLocation)
            continue
        }

        let attrs1 = try g1.getAttributes(edge: edge1.id)
        let attrs2 = try g2.getAttributes(edge: edge2.id)

        #expect(
            attrs1.count == attrs2.count,
            "Edge \(edge1.from)->\(edge1.to) should have same number of attributes",
            sourceLocation: sourceLocation)

        for (key, value1) in attrs1 {
            // Skip itemOrder - we verify order preservation separately
            if key.description == "edge.itemOrder" {
                continue
            }

            guard let value2 = attrs2[key] else {
                Issue.record("Edge \(edge1.from)->\(edge1.to) missing attribute \(key) in g2", sourceLocation: sourceLocation)
                continue
            }
            #expect(
                value1 == value2,
                "Edge \(edge1.from)->\(edge1.to) attribute \(key) should match: '\(value1)' vs '\(value2)'",
                sourceLocation: sourceLocation)

            #expect(
                type(of: value1) == type(of: value2),
                "Edge \(edge1.from)->\(edge1.to) attribute \(key) should have same type",
                sourceLocation: sourceLocation)
        }
    }

    #expect(g1.groups.count == g2.groups.count, "Graphs should have same number of groups", sourceLocation: sourceLocation)

    for group1 in g1.groups {
        guard let group2 = g2.groups.first(where: { $0.id.description == group1.id.description }) else {
            Issue.record("Group \(group1.id) not found in g2", sourceLocation: sourceLocation)
            continue
        }

        let attrs1 = try g1.getAttributes(group: group1)
        let attrs2 = try g2.getAttributes(group: group2)

        #expect(
            attrs1.count == attrs2.count,
            "Group \(group1.id) should have same number of attributes",
            sourceLocation: sourceLocation)

        for (key, value1) in attrs1 {
            guard let value2 = attrs2[key] else {
                Issue.record("Group \(group1.id) missing attribute \(key) in g2", sourceLocation: sourceLocation)
                continue
            }
            #expect(
                value1 == value2,
                "Group \(group1.id) attribute \(key) should match: '\(value1)' vs '\(value2)'",
                sourceLocation: sourceLocation)

            #expect(
                type(of: value1) == type(of: value2),
                "Group \(group1.id) attribute \(key) should have same type",
                sourceLocation: sourceLocation)
        }

        let nodes1 = try g1.getDirectNodes(group: group1)
        let nodes2 = try g2.getDirectNodes(group: group2)

        let nodeIds1 = Set(nodes1.map { $0.id.description })
        let nodeIds2 = Set(nodes2.map { $0.id.description })

        #expect(
            nodeIds1 == nodeIds2,
            "Group \(group1.id) should contain same nodes: \(nodeIds1) vs \(nodeIds2)",
            sourceLocation: sourceLocation)
    }

    for group1 in g1.groups {
        guard let group2 = g2.groups.first(where: { $0.id.description == group1.id.description }) else {
            continue
        }

        let parent1 = g1.parentGroup(of: group1)
        let parent2 = g2.parentGroup(of: group2)

        #expect(
            parent1?.id.description == parent2?.id.description,
            "Group \(group1.id) should have same parent: \(parent1?.id.description ?? "nil") vs \(parent2?.id.description ?? "nil")",
            sourceLocation: sourceLocation)
    }

    let graphAttrs1 = try g1.getGraphAttributes()
    let graphAttrs2 = try g2.getGraphAttributes()

    for (key, value1) in graphAttrs1 where key.description != "notation" {
        guard let value2 = graphAttrs2[key] else {
            Issue.record("Graph attribute \(key) missing in g2", sourceLocation: sourceLocation)
            continue
        }
        #expect(
            value1 == value2,
            "Graph attribute \(key) should match: '\(value1)' vs '\(value2)'",
            sourceLocation: sourceLocation)

        #expect(
            type(of: value1) == type(of: value2),
            "Graph attribute \(key) should have same type",
            sourceLocation: sourceLocation)
    }
}

@Suite
struct FullCycleTest {

    @Test
    func parseComplexGraph() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: complexGraphInput)

        // Verify basic structure (includes 4 extra unknown node types created by parser)
        #expect(graph.nodes.count == 54, "Expected 50 explicit + 4 unknown node types = 54 nodes")
        #expect(graph.edges.count == 70, "Expected 70 edges")

        let nonRootGroups = graph.groups.filter {
            $0.id.description != "vithanco.vgraph.rootGroup.only.for.internal.use"
        }
        #expect(nonRootGroups.count == 6, "Expected exactly 6 groups (A, B, C, D, E, F)")

        let graphId: String = try graph.get(graphAttribute: Attributes.Group.Id)
        #expect(graphId == "complexGraph")
        let graphLabel: String = try graph.get(graphAttribute: Attributes.Group.label)
        #expect(graphLabel == "Complex Test Graph")

        let groupA = graph.groups.first { $0.id.description == "groupA" }
        let groupB = graph.groups.first { $0.id.description == "groupB" }
        let groupC = graph.groups.first { $0.id.description == "groupC" }
        let groupD = graph.groups.first { $0.id.description == "groupD" }
        let groupE = graph.groups.first { $0.id.description == "groupE" }
        let groupF = graph.groups.first { $0.id.description == "groupF" }

        #expect(groupA != nil, "Group A should exist")
        #expect(groupB != nil, "Group B should exist")
        #expect(groupC != nil, "Group C should exist")
        #expect(groupD != nil, "Group D should exist (nested level 2)")
        #expect(groupE != nil, "Group E should exist (nested level 3)")
        #expect(groupF != nil, "Group F should exist")

        if let groupE = groupE {
            let parentOfE = graph.parentGroup(of: groupE)
            #expect(parentOfE?.id.description == "groupD", "Group E's parent should be Group D")

            if let groupD = parentOfE {
                let parentOfD = graph.parentGroup(of: groupD)
                #expect(parentOfD?.id.description == "groupC", "Group D's parent should be Group C")

                if let groupC = parentOfD {
                    let parentOfC = graph.parentGroup(of: groupC)
                    #expect(
                        parentOfC?.id.description == "vithanco.vgraph.rootGroup.only.for.internal.use",
                        "Group C's parent should be root group"
                    )
                }
            }
        }

        let nodeA1 = Node(string: "a1")
        #expect(graph.has(node: nodeA1))
        if let groupA = groupA {
            #expect(graph.group(of: nodeA1) == groupA, "Node a1 should be in group A")
        }

        let nodeE2 = Node(string: "e2")
        #expect(graph.has(node: nodeE2))
        if let groupE = groupE {
            #expect(graph.group(of: nodeE2) == groupE, "Node e2 should be in deeply nested group E")
        }

        let root1 = Node(string: "root1")
        #expect((try graph.nodeType(for: root1)) == Notations.Ibis.NodeTypes.question)

        let root3 = Node(string: "root3")
        #expect((try graph.nodeType(for: root3)) == Notations.Ibis.NodeTypes.answer)

        let root5 = Node(string: "root5")
        #expect((try graph.nodeType(for: root5)) == Notations.Ibis.NodeTypes.pro)

        let root6 = Node(string: "root6")
        #expect((try graph.nodeType(for: root6)) == Notations.Ibis.NodeTypes.con)

        try graph.ensure(node: root1, attribute: Attributes.Node.label, isSameAs: "Root Question 1")
        try graph.ensure(node: root1, attribute: Attributes.Node.fontsize, isSameAs: 16)

        let edge1 = graph.edges.first { $0.from == root1 && $0.to == root3 }
        #expect(edge1 != nil, "Edge from root1 to root3 should exist")
        if let edge1 = edge1 {
            #expect((try graph.edgeType(for: edge1.id)) == Notations.Ibis.EdgeTypes.questionToAnswer)
            try graph.ensure(edge: edge1, attribute: Attributes.Edge.label, isSameAs: "Initial analysis")
        }
    }

    @Test
    func exportToDotFormat() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: complexGraphInput)

        let exporter = DotExporter()
        let dotOutput = try exporter.export(graph: graph)

        #expect(dotOutput.hasPrefix("digraph"), "DOT should start with digraph")
        #expect(dotOutput.contains("subgraph cluster_groupA"), "DOT should contain group A")
        #expect(dotOutput.contains("subgraph cluster_groupE"), "DOT should contain nested group E")
        #expect(dotOutput.contains("root1"), "DOT should contain root nodes")
        #expect(dotOutput.contains("e2"), "DOT should contain deeply nested nodes")
    }

    @Test
    func testCompleteGraphEquality() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        let g1 = try parser.parse(source: complexGraphInput)

        let exporter = VGLExporter()
        let exportedGraph = try exporter.export(graph: g1)

        let g2 = try parser.parse(source: exportedGraph)

        try assertGraphsAreEqual(g1, g2)
    }

    @Test
    func fullCycleParseAndExportVGraph() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: complexGraphInput)

        let exporter = VGLExporter()
        let exportedVGraph = try exporter.export(graph: graph)

        #expect(!exportedVGraph.isEmpty, "Exported VGL should not be empty")
        #expect(exportedVGraph.contains("vgraph complexGraph: IBIS"), "Exported VGL should contain graph declaration")
        #expect(exportedVGraph.contains("node root1: Question"), "Exported VGL should contain nodes")
        #expect(exportedVGraph.contains("edge"), "Exported VGL should contain edges")
        #expect(exportedVGraph.contains("group groupA"), "Exported VGL should contain groups")

        let graph2 = try parser.parse(source: exportedVGraph)

        #expect(graph2.nodes.count == graph.nodes.count, "Node count should be preserved")
        #expect(graph2.edges.count == graph.edges.count, "Edge count should be preserved")
        #expect(graph2.groups.count == graph.groups.count, "Group count should be preserved")

        let graphId1: String = try graph.get(graphAttribute: Attributes.Group.Id)
        let graphId2: String = try graph2.get(graphAttribute: Attributes.Group.Id)
        #expect(graphId1 == graphId2, "Graph ID should be preserved")

        let graphLabel1: String = try graph.get(graphAttribute: Attributes.Group.label)
        let graphLabel2: String = try graph2.get(graphAttribute: Attributes.Group.label)
        #expect(graphLabel1 == graphLabel2, "Graph label should be preserved")

        let root1 = Node(string: "root1")
        let root1Label1: String = try graph.get(node: root1, attribute: Attributes.Node.label)
        let root1Label2: String = try graph2.get(node: root1, attribute: Attributes.Node.label)
        #expect(root1Label1 == root1Label2, "Node labels should be preserved")

        let root1Fontsize1: Double = try graph.get(node: root1, attribute: Attributes.Node.fontsize)
        let root1Fontsize2: Double = try graph2.get(node: root1, attribute: Attributes.Node.fontsize)
        #expect(root1Fontsize1 == root1Fontsize2, "Node fontsize should be preserved")

        let edge1 = graph.edges.first { $0.from == Node(string: "root1") && $0.to == Node(string: "root3") }!
        let edge2 = graph2.edges.first { $0.from == Node(string: "root1") && $0.to == Node(string: "root3") }!

        let edge1Label: String = try graph.get(edge: edge1.id, attribute: Attributes.Edge.label)
        let edge2Label: String = try graph2.get(edge: edge2.id, attribute: Attributes.Edge.label)
        #expect(edge1Label == edge2Label, "Edge labels should be preserved")

        let groupE2 = graph2.groups.first { $0.id.description == "groupE" }!
        let parentE2 = graph2.parentGroup(of: groupE2)
        #expect(parentE2?.id.description == "groupD", "Group nesting should be preserved")
    }

    @Test
    func verifyGroupAttributesPreserved() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: complexGraphInput)

        guard let groupA = graph.groups.first(where: { $0.id.description == "groupA" }) else {
            Issue.record("Group A should exist")
            return
        }

        try graph.ensure(group: groupA, attribute: Attributes.Group.label, isSameAs: "Research and Analysis")
        try graph.ensure(group: groupA, attribute: Attributes.Group.style, isSameAs: .filled)

        guard let groupE = graph.groups.first(where: { $0.id.description == "groupE" }) else {
            Issue.record("Group E should exist")
            return
        }

        try graph.ensure(group: groupE, attribute: Attributes.Group.label, isSameAs: "CI-CD Pipeline")

        // Verify group E is at level 3 (has 2 parent groups before root)
        var depth = 0
        var currentGroup: Group? = groupE

        while let group = currentGroup {
            if group.id.description == "vithanco.vgraph.rootGroup.only.for.internal.use" {
                break
            }
            depth += 1
            currentGroup = graph.parentGroup(of: group)
        }

        #expect(depth == 3, "Group E should be at depth 3 (groupE -> groupD -> groupC -> root)")
    }
}

@Test
func debugWriteExport() throws {
    let parser = VGraphParser(logger: NoOpLogger())
    let graph = try parser.parse(source: complexGraphInput)

    let exporter = VGLExporter()
    let exported = try exporter.export(graph: graph)

    try exported.write(toFile: "/tmp/full_export.vgl", atomically: true, encoding: .utf8)
}

@Test
func debugDotExport() throws {
    let parser = VGraphParser(logger: NoOpLogger())
    let graph = try parser.parse(source: complexGraphInput)

    let exporter = DotExporter()
    let exported = try exporter.export(graph: graph)

    try exported.write(toFile: "/tmp/full_export.dot", atomically: true, encoding: .utf8)
}

@Suite("VGL Group Export Tests")
struct VGLGroupExportTests {

    @Test
    func testGroupAttributesAreExported() throws {
        let vgraphInput = """
            vgraph testGraph: IBIS "Test Graph" {
                group testGroup "Test Group Label" {
                    style: filled;
                    color: lightblue;
                    node n1: Question "Node 1";
                    node n2: Answer "Node 2";
                };
            }
            """
        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: vgraphInput)

        let exporter = VGLExporter()
        let vglOutput = try exporter.export(graph: graph)

        #expect(vglOutput.contains("group testGroup"), "Group declaration should exist")
        #expect(vglOutput.contains("\"Test Group Label\""), "Group label should be in declaration")

        #expect(vglOutput.contains("style: filled"), "Group style attribute should be exported")
        #expect(vglOutput.contains("color: lightblue"), "Group color attribute should be exported")
    }

    @Test
    func testNodesAreInsideTheirGroups() throws {
        let vgraphInput = """
            vgraph testGraph: IBIS "Test Graph" {
                node root: Question "Root Node";

                group groupA "Group A" {
                    node a1: Question "Node A1";
                    node a2: Answer "Node A2";
                };

                group groupB "Group B" {
                    node b1: Question "Node B1";

                    group groupB_nested "Nested Group" {
                        node b1_1: Answer "Node B1.1";
                    };
                };
            }
            """
        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: vgraphInput)

        let exporter = VGLExporter()
        let vglOutput = try exporter.export(graph: graph)

        let lines = vglOutput.components(separatedBy: "\n")

        guard let groupAStart = lines.firstIndex(where: { $0.contains("group groupA") }) else {
            Issue.record("group groupA not found")
            return
        }
        guard let groupAEnd = lines[groupAStart...].firstIndex(where: { $0.trimmed() == "}" }) else {
            Issue.record("groupA closing brace not found")
            return
        }

        let groupABlock = lines[groupAStart...groupAEnd].joined(separator: "\n")
        #expect(groupABlock.contains("node a1:"), "Node a1 should be inside groupA block")
        #expect(groupABlock.contains("node a2:"), "Node a2 should be inside groupA block")
        #expect(!groupABlock.contains("node b1:"), "Node b1 should NOT be inside groupA block")
        #expect(!groupABlock.contains("node root:"), "Root node should NOT be inside groupA block")

        guard
            let groupBStart = lines.firstIndex(where: {
                $0.contains("group groupB") && !$0.contains("groupB_nested")
            })
        else {
            Issue.record("group groupB not found")
            return
        }

        // Find the last closing brace for groupB (after nested group)
        guard let groupBEnd = lines[groupBStart...].lastIndex(where: { $0.trimmed() == "}" }) else {
            Issue.record("groupB closing brace not found")
            return
        }

        let groupBBlock = lines[groupBStart...groupBEnd].joined(separator: "\n")
        #expect(groupBBlock.contains("node b1:"), "Node b1 should be inside groupB block")
        #expect(groupBBlock.contains("group groupB_nested"), "Nested group should be inside groupB block")
        #expect(groupBBlock.contains("node b1_1:"), "Node b1_1 should be inside groupB block (nested)")
        #expect(!groupBBlock.contains("node a1:"), "Node a1 should NOT be inside groupB block")

        let rootNodeLine = lines.firstIndex(where: { $0.contains("node root:") })
        #expect(rootNodeLine != nil, "Root node should exist in output")
        if let rootLine = rootNodeLine {
            #expect(rootLine < groupAStart, "Root node should appear before groups")
        }
    }

    @Test
    func testNestedGroupsWithAttributes() throws {
        let vgraphInput = """
            vgraph testGraph: IBIS "Test Graph" {
                group outer "Outer Group" {
                    style: filled;
                    color: lightgray;

                    node o1: Question "Outer Node";

                    group inner "Inner Group" {
                        style: dashed;
                        color: lightblue;

                        node i1: Answer "Inner Node";
                    };
                };
            }
            """
        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: vgraphInput)

        let exporter = VGLExporter()
        let vglOutput = try exporter.export(graph: graph)

        #expect(vglOutput.contains("group outer"), "Outer group should exist")
        #expect(vglOutput.contains("\"Outer Group\""), "Outer group label should exist")

        let lines = vglOutput.components(separatedBy: "\n")
        guard let outerStart = lines.firstIndex(where: { $0.contains("group outer") }) else {
            Issue.record("group outer not found")
            return
        }

        guard let outerEnd = lines[outerStart...].lastIndex(where: { $0.trimmed() == "}" }) else {
            Issue.record("outer group closing brace not found")
            return
        }

        let outerBlock = lines[outerStart...outerEnd].joined(separator: "\n")

        #expect(outerBlock.contains("style: filled"), "Outer group should have style attribute")
        #expect(outerBlock.contains("color: lightgray"), "Outer group should have color attribute")

        #expect(outerBlock.contains("group inner"), "Inner group should be nested inside outer group")
        #expect(outerBlock.contains("\"Inner Group\""), "Inner group label should exist")

        #expect(outerBlock.contains("style: dashed"), "Inner group should have style attribute")
        #expect(outerBlock.contains("color: lightblue"), "Inner group should have color attribute")

        #expect(outerBlock.contains("node o1:"), "Outer node should be in outer group")
        #expect(outerBlock.contains("node i1:"), "Inner node should be in nested structure")
    }

    @Test
    func testMultipleGroupsPreserveStructure() throws {
        let vgraphInput = """
            vgraph testGraph: IBIS "Test Graph" {
                group g1 "Group 1" {
                    color: red;
                    node n1: Question "Node 1";
                };

                group g2 "Group 2" {
                    color: blue;
                    node n2: Answer "Node 2";
                };

                group g3 "Group 3" {
                    color: green;
                    node n3: Pro "Node 3";
                };
            }
            """
        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: vgraphInput)

        let exporter = VGLExporter()
        let vglOutput = try exporter.export(graph: graph)

        #expect(vglOutput.contains("group g1"), "Group g1 should exist")
        #expect(vglOutput.contains("group g2"), "Group g2 should exist")
        #expect(vglOutput.contains("group g3"), "Group g3 should exist")

        #expect(vglOutput.contains("color: red"), "Group g1 color should be exported")
        #expect(vglOutput.contains("color: blue"), "Group g2 color should be exported")
        #expect(vglOutput.contains("color: green"), "Group g3 color should be exported")

        let lines = vglOutput.components(separatedBy: "\n")

        if let g1Start = lines.firstIndex(where: { $0.contains("group g1") }),
            let g1End = lines[g1Start...].firstIndex(where: { $0.trimmed() == "}" })
        {
            let g1Block = lines[g1Start...g1End].joined(separator: "\n")
            #expect(g1Block.contains("node n1:"), "Node n1 should be in group g1")
            #expect(!g1Block.contains("node n2:"), "Node n2 should NOT be in group g1")
            #expect(!g1Block.contains("node n3:"), "Node n3 should NOT be in group g1")
        } else {
            Issue.record("Group g1 block not found properly")
        }
    }

    @Test
    func testGraphLevelPropertiesAreExported() throws {
        let vgraphInput = """
            vgraph testGraph: IBIS "Test Graph" {
                rankdir: LR;
                fontcolor: darkblue;
                labeljust: l;

                node n1: Question "Node 1";
            }
            """
        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: vgraphInput)

        let exporter = VGLExporter()
        let vglOutput = try exporter.export(graph: graph)

        #expect(vglOutput.contains("vgraph testGraph: IBIS"), "Graph declaration should exist")

        // Verify graph-level properties are NOT exported inline with vgraph declaration
        // They should appear as separate statements inside the graph block
        // Note: Currently VGLExporter doesn't export graph-level attributes beyond label
        // This test documents the expected behavior
    }

    @Test
    func testComplexGraphWithPropertiesRoundTrip() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        let graph1 = try parser.parse(source: complexGraphInput)

        let layoutDirStr: String = try graph1.get(graphAttribute: Attributes.Group.layoutDirection)
        #expect(layoutDirStr == "LR", "Layout direction should be LR (stored as graphviz value)")

        let fontColorStr: String = try graph1.get(graphAttribute: Attributes.Group.fontcolor)
        #expect(fontColorStr == "darkblue", "Font color should be darkblue")

        let labelJustStr: String = try graph1.get(graphAttribute: Attributes.Group.labeljust)
        #expect(labelJustStr == "l", "Label justification should be left")

        let exporter = VGLExporter()
        let exported = try exporter.export(graph: graph1)
        let graph2 = try parser.parse(source: exported)

        let layoutDir2: String = try graph2.get(graphAttribute: Attributes.Group.layoutDirection)
        #expect(layoutDir2 == layoutDirStr, "Layout direction should be preserved")

        let fontColor2: String = try graph2.get(graphAttribute: Attributes.Group.fontcolor)
        #expect(fontColor2 == fontColorStr, "Font color should be preserved")

        let labelJust2: String = try graph2.get(graphAttribute: Attributes.Group.labeljust)
        #expect(labelJust2 == labelJustStr, "Label justification should be preserved")
    }
}

// MARK: - Impact Mapping Full Cycle Tests

@Suite("Impact Mapping Full Cycle Tests")
struct ImpactMappingFullCycleTests {

    @Test
    func parseImpactMappingGraph() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: impactMappingInput)

        // Verify basic structure
        #expect(graph.nodes.count == 30, "Expected 30 nodes (3 goals + 7 actors + 9 impacts + 11 deliverables)")

        // Total edges: counting from the input
        // goal1: 2, actor1: 2, actor2: 1, impact1: 1, impact2: 1, impact3: 1
        // goal2: 3, actor3: 2, actor4: 1, actor5: 1, impact4: 2, impact5: 1, impact7: 2
        // goal3: 2, actor6: 2, actor7: 2, impact8: 1, impact9: 2
        // Total: 2+2+1+1+1+1 + 3+2+1+1+2+1+2 + 2+2+2+1+2 = 29 edges
        #expect(graph.edges.count == 29, "Expected 29 edges")

        let nonRootGroups = graph.groups.filter {
            $0.id.description != "vithanco.vgraph.rootGroup.only.for.internal.use"
        }
        #expect(nonRootGroups.count == 4, "Expected 4 groups (marketingTeam, productTeam, developmentTeam, operationsTeam)")

        let graphId: String = try graph.get(graphAttribute: Attributes.Group.Id)
        #expect(graphId == "productLaunch", "Graph ID should be 'productLaunch'")

        let graphLabel: String = try graph.get(graphAttribute: Attributes.Group.label)
        #expect(graphLabel == "Product Launch Strategy", "Graph label should be 'Product Launch Strategy'")

        let notationString: String = graph.notationName
        #expect(notationString == Notations.ImpactMapping.id.description, "Notation should be ImpactMapping")

        let goal1 = Node(string: "goal1")
        #expect(try graph.nodeType(for: goal1) == Notations.ImpactMapping.NodeTypes.goal, "goal1 should be Goal type")

        let actor1 = Node(string: "actor1")
        #expect(try graph.nodeType(for: actor1) == Notations.ImpactMapping.NodeTypes.actor, "actor1 should be Actor type")

        let impact1 = Node(string: "impact1")
        #expect(try graph.nodeType(for: impact1) == Notations.ImpactMapping.NodeTypes.impact, "impact1 should be Impact type")

        let deliv1 = Node(string: "deliv1")
        #expect(try graph.nodeType(for: deliv1) == Notations.ImpactMapping.NodeTypes.deliverable, "deliv1 should be Deliverable type")

        try graph.ensure(node: goal1, attribute: Attributes.Node.label, isSameAs: "Increase market share by 20%")
        try graph.ensure(node: actor1, attribute: Attributes.Node.label, isSameAs: "Marketing Director")

        let edgeGoalToActor = graph.edges.first { $0.from == goal1 && $0.to == actor1 }
        #expect(edgeGoalToActor != nil, "Edge from goal1 to actor1 should exist")
        if let edge = edgeGoalToActor {
            #expect(
                try graph.edgeType(for: edge.id) == Notations.ImpactMapping.EdgeTypes.goalToActor,
                "Edge should be goal_to_actor type"
            )
            try graph.ensure(edge: edge, attribute: Attributes.Edge.label, isSameAs: "Leads initiative")
        }

        let impact7 = Node(string: "impact7")
        let deliv4 = Node(string: "deliv4")
        let edgeImpactToDeliv = graph.edges.first { $0.from == impact7 && $0.to == deliv4 }
        #expect(edgeImpactToDeliv != nil, "Edge from impact7 to deliv4 should exist")
        if let edge = edgeImpactToDeliv {
            #expect(
                try graph.edgeType(for: edge.id) == Notations.ImpactMapping.EdgeTypes.impactToDeliverable,
                "Edge should be impact_to_deliverable type"
            )
        }

        let productTeamGroup = graph.groups.first { $0.id.description == "productTeam" }
        let developmentTeamGroup = graph.groups.first { $0.id.description == "developmentTeam" }

        #expect(productTeamGroup != nil, "productTeam group should exist")
        #expect(developmentTeamGroup != nil, "developmentTeam group should exist")

        if let devTeam = developmentTeamGroup {
            let parent = graph.parentGroup(of: devTeam)
            #expect(parent?.id.description == "productTeam", "developmentTeam's parent should be productTeam")
        }

        let marketingTeamGroup = graph.groups.first { $0.id.description == "marketingTeam" }
        #expect(marketingTeamGroup != nil, "marketingTeam group should exist")
        if let group = marketingTeamGroup {
            #expect(graph.group(of: actor1) == group, "actor1 should be in marketingTeam")
        }

        if let group = developmentTeamGroup {
            let actor5 = Node(string: "actor5")
            #expect(graph.group(of: actor5) == group, "actor5 should be in developmentTeam")
        }
    }

    @Test
    func testImpactMappingCompleteGraphEquality() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        let g1 = try parser.parse(source: impactMappingInput)

        let exporter = VGLExporter()
        let exportedGraph = try exporter.export(graph: g1)

        let g2 = try parser.parse(source: exportedGraph)

        try assertGraphsAreEqual(g1, g2)
    }

    @Test
    func exportImpactMappingToDotFormat() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: impactMappingInput)

        let exporter = DotExporter()
        let dotOutput = try exporter.export(graph: graph)

        #expect(dotOutput.hasPrefix("digraph"), "DOT should start with digraph")
        #expect(dotOutput.contains("subgraph cluster_marketingTeam"), "DOT should contain marketingTeam group")
        #expect(dotOutput.contains("subgraph cluster_productTeam"), "DOT should contain productTeam group")
        #expect(dotOutput.contains("subgraph cluster_developmentTeam"), "DOT should contain nested developmentTeam group")
        #expect(dotOutput.contains("goal1"), "DOT should contain goal nodes")
        #expect(dotOutput.contains("actor1"), "DOT should contain actor nodes")
        #expect(dotOutput.contains("impact1"), "DOT should contain impact nodes")
        #expect(dotOutput.contains("deliv1"), "DOT should contain deliverable nodes")
    }

    @Test
    func fullCycleParseAndExportImpactMapping() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: impactMappingInput)

        let exporter = VGLExporter()
        let exportedVGraph = try exporter.export(graph: graph)

        #expect(!exportedVGraph.isEmpty, "Exported VGL should not be empty")
        #expect(exportedVGraph.contains("vgraph productLaunch: ImpactMapping"), "Exported VGL should contain graph declaration")
        #expect(exportedVGraph.contains("node goal1: Goal"), "Exported VGL should contain goal nodes")
        #expect(exportedVGraph.contains("node actor1: Actor"), "Exported VGL should contain actor nodes")
        #expect(exportedVGraph.contains("node impact1: Impact"), "Exported VGL should contain impact nodes")
        #expect(exportedVGraph.contains("node deliv1: Deliverable"), "Exported VGL should contain deliverable nodes")
        #expect(exportedVGraph.contains("edge"), "Exported VGL should contain edges")
        #expect(exportedVGraph.contains("group marketingTeam"), "Exported VGL should contain groups")

        let graph2 = try parser.parse(source: exportedVGraph)

        #expect(graph2.nodes.count == graph.nodes.count, "Node count should be preserved")
        #expect(graph2.edges.count == graph.edges.count, "Edge count should be preserved")
        #expect(graph2.groups.count == graph.groups.count, "Group count should be preserved")

        let graphId1: String = try graph.get(graphAttribute: Attributes.Group.Id)
        let graphId2: String = try graph2.get(graphAttribute: Attributes.Group.Id)
        #expect(graphId1 == graphId2, "Graph ID should be preserved")

        let graphLabel1: String = try graph.get(graphAttribute: Attributes.Group.label)
        let graphLabel2: String = try graph2.get(graphAttribute: Attributes.Group.label)
        #expect(graphLabel1 == graphLabel2, "Graph label should be preserved")

        let notationString1: String = graph.notationName
        let notationString2: String = graph2.notationName
        #expect(notationString1 == notationString2, "Notation should be preserved")

        let goal1 = Node(string: "goal1")
        let goal1Label1: String = try graph.get(node: goal1, attribute: Attributes.Node.label)
        let goal1Label2: String = try graph2.get(node: goal1, attribute: Attributes.Node.label)
        #expect(goal1Label1 == goal1Label2, "Node labels should be preserved")

        let goal1Fontsize1: Double = try graph.get(node: goal1, attribute: Attributes.Node.fontsize)
        let goal1Fontsize2: Double = try graph2.get(node: goal1, attribute: Attributes.Node.fontsize)
        #expect(goal1Fontsize1 == goal1Fontsize2, "Node fontsize should be preserved")

        let edge1 = graph.edges.first { $0.from == Node(string: "goal1") && $0.to == Node(string: "actor1") }!
        let edge2 = graph2.edges.first { $0.from == Node(string: "goal1") && $0.to == Node(string: "actor1") }!

        let edge1Label: String = try graph.get(edge: edge1.id, attribute: Attributes.Edge.label)
        let edge2Label: String = try graph2.get(edge: edge2.id, attribute: Attributes.Edge.label)
        #expect(edge1Label == edge2Label, "Edge labels should be preserved")

        let developmentTeam2 = graph2.groups.first { $0.id.description == "developmentTeam" }!
        let parentE2 = graph2.parentGroup(of: developmentTeam2)
        #expect(parentE2?.id.description == "productTeam", "Group nesting should be preserved")
    }

    @Test
    func verifyImpactMappingGroupAttributesPreserved() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: impactMappingInput)

        guard let marketingTeam = graph.groups.first(where: { $0.id.description == "marketingTeam" }) else {
            Issue.record("marketingTeam should exist")
            return
        }

        try graph.ensure(group: marketingTeam, attribute: Attributes.Group.label, isSameAs: "Marketing Team")
        try graph.ensure(group: marketingTeam, attribute: Attributes.Group.style, isSameAs: .filled)

        guard let developmentTeam = graph.groups.first(where: { $0.id.description == "developmentTeam" }) else {
            Issue.record("developmentTeam should exist")
            return
        }

        try graph.ensure(group: developmentTeam, attribute: Attributes.Group.label, isSameAs: "Development Team")

        // Verify developmentTeam is at depth 2 (developmentTeam -> productTeam -> root)
        var depth = 0
        var currentGroup: Group? = developmentTeam

        while let group = currentGroup {
            if group.id.description == "vithanco.vgraph.rootGroup.only.for.internal.use" {
                break
            }
            depth += 1
            currentGroup = graph.parentGroup(of: group)
        }

        #expect(depth == 2, "developmentTeam should be at depth 2 (developmentTeam -> productTeam -> root)")
    }

    @Test
    func testConceptMap() throws {
        let input = """
            vgraph learningCM: ConceptMap "Learning Concept Map" {
                node c1: Concept "Student";
                node r1: Relation "learns";
                node c2: Concept "Subject";
                node r2: Relation "requires";
                node c3: EmphasizedConcept "Practice";

                edge c1 -> r1: concept_to_relation;
                edge r1 -> c2: relation_to_concept;
                edge c2 -> r2: concept_to_relation;
                edge r2 -> c3: relation_to_emphasized_concept;
            }
            """

        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: input)

        #expect(graph.nodes.count == 5, "Graph should have 5 nodes")
        #expect(graph.edges.count == 4, "Graph should have 4 edges")

        #expect(graph.nodes.contains(Node(string: "c1")), "Node c1 should exist")
        #expect(graph.nodes.contains(Node(string: "r1")), "Node r1 should exist")
        #expect(graph.nodes.contains(Node(string: "c2")), "Node c2 should exist")
        #expect(graph.nodes.contains(Node(string: "c3")), "Node c3 should exist")

        let hasEdges = graph.edges.count > 0
        #expect(hasEdges, "Graph should have edges")

        let exporter = VGLExporter()
        let exported = try exporter.export(graph: graph)
        #expect(exported.contains("ConceptMap"), "Exported VGL should contain ConceptMap")
        #expect(exported.contains("Concept"), "Exported VGL should contain Concept nodes")
        #expect(exported.contains("Relation"), "Exported VGL should contain Relation nodes")

        let reparsed = try parser.parse(source: exported)
        #expect(reparsed.nodes.count == graph.nodes.count, "Node count should be preserved")
        #expect(reparsed.edges.count == graph.edges.count, "Edge count should be preserved")
    }
}

// MARK: - Causal Loop Diagram Full Cycle Tests

@Suite("Causal Loop Diagram Full Cycle Tests")
struct CausalLoopDiagramFullCycleTests {

    @Test
    func testCausalLoopDiagram() throws {
        let input = """
            vgraph populationCLD: CLD "Population Dynamics" {
                node births: Stock "Births";
                node population: Stock "Population";
                node deaths: Stock "Deaths";
                node resources: Stock "Available Resources";

                edge births -> population: same;
                edge population -> deaths: same;
                edge deaths -> population: opposite;
                edge population -> resources: opposite;
                edge resources -> births: same;
            }
            """

        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: input)

        #expect(graph.nodes.count == 4, "Graph should have 4 nodes")
        #expect(graph.edges.count == 5, "Graph should have 5 edges")

        #expect(graph.nodes.contains(Node(string: "births")), "Node births should exist")
        #expect(graph.nodes.contains(Node(string: "population")), "Node population should exist")
        #expect(graph.nodes.contains(Node(string: "deaths")), "Node deaths should exist")
        #expect(graph.nodes.contains(Node(string: "resources")), "Node resources should exist")

        let birthsNode = Node(string: "births")
        let birthsType = try graph.nodeType(for: birthsNode)
        #expect(birthsType == Notations.CausalLoopDiagram.NodeTypes.stock, "births should be a Stock node")

        let exporter = VGLExporter()
        let exported = try exporter.export(graph: graph)
        #expect(exported.contains("CLD"), "Exported VGL should contain CLD")
        #expect(exported.contains("Stock"), "Exported VGL should contain Stock nodes")
        #expect(exported.contains("same"), "Exported VGL should contain same edge type")
        #expect(exported.contains("opposite"), "Exported VGL should contain opposite edge type")

        let reparsed = try parser.parse(source: exported)
        #expect(reparsed.nodes.count == graph.nodes.count, "Node count should be preserved")
        #expect(reparsed.edges.count == graph.edges.count, "Edge count should be preserved")
    }

    @Test
    func testCausalLoopDiagramCompleteGraphEquality() throws {
        let input = """
            vgraph armsCLD: CLD "Arms Race" {
                node threatA: Stock "Threat from A";
                node armsA: Stock "Arms of A";
                node threatB: Stock "Threat from B";
                node armsB: Stock "Arms of B";

                edge threatA -> armsB: same;
                edge armsB -> threatB: same;
                edge threatB -> armsA: same;
                edge armsA -> threatA: same;
            }
            """

        let parser = VGraphParser(logger: NoOpLogger())
        let g1 = try parser.parse(source: input)

        let exporter = VGLExporter()
        let exportedGraph = try exporter.export(graph: g1)

        let g2 = try parser.parse(source: exportedGraph)

        try assertGraphsAreEqual(g1, g2)
    }
}

// MARK: - Current Reality Tree Full Cycle Tests

/// A Current Reality Tree test graph demonstrating root cause analysis
/// Uses all node types: UndesirableEffect, IntermediateEffect, DesirableEffect, Given, Changeable, AndJunctor
/// (Sufficient-cause logic: multiple unjoined causes are implicitly OR; only AND is an explicit junctor.)
let currentRealityTreeInput = """
    vgraph salesProblem: CRT "Sales Decline Analysis" {
        // Undesirable Effects (the problems we observe)
        node ude1: UndesirableEffect "Sales revenue declining";
        node ude2: UndesirableEffect "Customer complaints increasing";
        node ude3: UndesirableEffect "Market share decreasing";

        // Intermediate Effects (neutral outcomes in the causal chain)
        node ie1: IntermediateEffect "Customers switching to competitors";
        node ie2: IntermediateEffect "Product perceived as outdated";
        node ie3: IntermediateEffect "Support response time is slow";

        // Desirable Effects (things we want to keep)
        node de1: DesirableEffect "Brand reputation still strong";

        // Given (unchangeable facts)
        node g1: Given "Market is highly competitive";
        node g2: Given "Customer expectations keep rising";

        // Changeable (root causes we can address)
        node c1: Changeable "Product development cycle is too long";
        node c2: Changeable "Support team is understaffed";
        node c3: Changeable "No customer feedback loop";

        // And Junctor (multiple conditions required together)
        node and1: AndJunctor;

        // Edges: causes flow upward (from -> to means "from causes to")
        // Root causes leading to intermediate effects
        edge c1 -> ie2: changeable_causes_intermediate;
        edge c3 -> ie2: changeable_causes_intermediate;
        edge c2 -> ie3: changeable_causes_intermediate;

        // Given facts contributing to situation
        edge g1 -> ie1: given_causes_intermediate;
        edge g2 -> and1: given_to_and_junctor;
        edge ie2 -> and1: intermediate_to_and_junctor;

        // And junctor combining conditions
        edge and1 -> ie1: and_junctor_causes_intermediate;

        // Alternative causes implicitly OR'd into ude2
        edge ie1 -> ude2: intermediate_causes_undesirable;
        edge ie3 -> ude2: intermediate_causes_undesirable;

        // Intermediate effects leading to undesirable effects
        edge ie1 -> ude1: intermediate_causes_undesirable;
        edge ie1 -> ude3: intermediate_causes_undesirable;

        // Brand reputation affected but still desirable
        edge ie2 -> de1: intermediate_causes_desirable;
    }
    """

@Suite("Current Reality Tree Full Cycle Tests")
struct CurrentRealityTreeFullCycleTests {

    @Test
    func parseCRTGraph() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: currentRealityTreeInput)

        // Verify basic structure: 3 UDE + 3 IE + 1 DE + 2 Given + 3 Changeable + 1 And = 13 nodes
        #expect(graph.nodes.count == 13, "Expected 13 nodes")

        #expect(graph.edges.count == 12, "Expected 12 edges")

        let graphId: String = try graph.get(graphAttribute: Attributes.Group.Id)
        #expect(graphId == "salesProblem", "Graph ID should be 'salesProblem'")

        let graphLabel: String = try graph.get(graphAttribute: Attributes.Group.label)
        #expect(graphLabel == "Sales Decline Analysis", "Graph label should be 'Sales Decline Analysis'")

        let notationString: String = graph.notationName
        #expect(notationString == Notations.CurrentRealityTree.id.description, "Notation should be CRT")

        let ude1 = Node(string: "ude1")
        #expect(try graph.nodeType(for: ude1) == Notations.CurrentRealityTree.NodeTypes.undesirableEffect, "ude1 should be UndesirableEffect type")

        let ie1 = Node(string: "ie1")
        #expect(try graph.nodeType(for: ie1) == Notations.CurrentRealityTree.NodeTypes.intermediateEffect, "ie1 should be IntermediateEffect type")

        let de1 = Node(string: "de1")
        #expect(try graph.nodeType(for: de1) == Notations.CurrentRealityTree.NodeTypes.desirableEffect, "de1 should be DesirableEffect type")

        let g1 = Node(string: "g1")
        #expect(try graph.nodeType(for: g1) == Notations.CurrentRealityTree.NodeTypes.given, "g1 should be Given type")

        let c1 = Node(string: "c1")
        #expect(try graph.nodeType(for: c1) == Notations.CurrentRealityTree.NodeTypes.changeable, "c1 should be Changeable type")

        let and1 = Node(string: "and1")
        #expect(try graph.nodeType(for: and1) == Notations.CurrentRealityTree.NodeTypes.andJunctor, "and1 should be AndJunctor type")

        try graph.ensure(node: ude1, attribute: Attributes.Node.label, isSameAs: "Sales revenue declining")
        try graph.ensure(node: g1, attribute: Attributes.Node.label, isSameAs: "Market is highly competitive")
        try graph.ensure(node: c1, attribute: Attributes.Node.label, isSameAs: "Product development cycle is too long")

        let edgeChangeableToIntermediate = graph.edges.first { $0.from == c1 && $0.to == ie1 || $0.from == c1 && $0.to == Node(string: "ie2") }
        #expect(edgeChangeableToIntermediate != nil, "Edge from changeable to intermediate should exist")
        if let edge = edgeChangeableToIntermediate {
            #expect(
                try graph.edgeType(for: edge.id) == Notations.CurrentRealityTree.EdgeTypes.changeableCausesIntermediate,
                "Edge should be changeable_causes_intermediate type"
            )
        }

        let edgeAndJunctorToIntermediate = graph.edges.first { $0.from == and1 && $0.to == ie1 }
        #expect(edgeAndJunctorToIntermediate != nil, "Edge from AndJunctor to IntermediateEffect should exist")
        if let edge = edgeAndJunctorToIntermediate {
            #expect(
                try graph.edgeType(for: edge.id) == Notations.CurrentRealityTree.EdgeTypes.andJunctorCausesIntermediate,
                "Edge should be and_junctor_causes_intermediate type"
            )
        }
    }

    @Test
    func testCRTCompleteGraphEquality() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        let g1 = try parser.parse(source: currentRealityTreeInput)

        let exporter = VGLExporter()
        let exportedGraph = try exporter.export(graph: g1)

        let g2 = try parser.parse(source: exportedGraph)

        try assertGraphsAreEqual(g1, g2)
    }

    @Test
    func exportCRTToDotFormat() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: currentRealityTreeInput)

        let exporter = DotExporter()
        let dotOutput = try exporter.export(graph: graph)

        #expect(dotOutput.hasPrefix("digraph"), "DOT should start with digraph")
        #expect(dotOutput.contains("ude1"), "DOT should contain undesirable effect nodes")
        #expect(dotOutput.contains("ie1"), "DOT should contain intermediate effect nodes")
        #expect(dotOutput.contains("de1"), "DOT should contain desirable effect nodes")
        #expect(dotOutput.contains("g1"), "DOT should contain given nodes")
        #expect(dotOutput.contains("c1"), "DOT should contain changeable nodes")
        #expect(dotOutput.contains("and1"), "DOT should contain and junctor nodes")
    }

    @Test
    func fullCycleParseAndExportCRT() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: currentRealityTreeInput)

        let exporter = VGLExporter()
        let exportedVGraph = try exporter.export(graph: graph)

        #expect(!exportedVGraph.isEmpty, "Exported VGL should not be empty")
        #expect(exportedVGraph.contains("vgraph salesProblem: CRT"), "Exported VGL should contain graph declaration")
        #expect(exportedVGraph.contains("node ude1: UndesirableEffect"), "Exported VGL should contain undesirable effect nodes")
        #expect(exportedVGraph.contains("node ie1: IntermediateEffect"), "Exported VGL should contain intermediate effect nodes")
        #expect(exportedVGraph.contains("node de1: DesirableEffect"), "Exported VGL should contain desirable effect nodes")
        #expect(exportedVGraph.contains("node g1: Given"), "Exported VGL should contain given nodes")
        #expect(exportedVGraph.contains("node c1: Changeable"), "Exported VGL should contain changeable nodes")
        #expect(exportedVGraph.contains("node and1: AndJunctor"), "Exported VGL should contain and junctor nodes")
        #expect(exportedVGraph.contains("edge"), "Exported VGL should contain edges")

        let graph2 = try parser.parse(source: exportedVGraph)

        #expect(graph2.nodes.count == graph.nodes.count, "Node count should be preserved")
        #expect(graph2.edges.count == graph.edges.count, "Edge count should be preserved")

        let graphId1: String = try graph.get(graphAttribute: Attributes.Group.Id)
        let graphId2: String = try graph2.get(graphAttribute: Attributes.Group.Id)
        #expect(graphId1 == graphId2, "Graph ID should be preserved")

        let graphLabel1: String = try graph.get(graphAttribute: Attributes.Group.label)
        let graphLabel2: String = try graph2.get(graphAttribute: Attributes.Group.label)
        #expect(graphLabel1 == graphLabel2, "Graph label should be preserved")

        let notationString1: String = graph.notationName
        let notationString2: String = graph2.notationName
        #expect(notationString1 == notationString2, "Notation should be preserved")

        let ude1 = Node(string: "ude1")
        let ude1Label1: String = try graph.get(node: ude1, attribute: Attributes.Node.label)
        let ude1Label2: String = try graph2.get(node: ude1, attribute: Attributes.Node.label)
        #expect(ude1Label1 == ude1Label2, "Node labels should be preserved")
    }

    @Test
    func verifyCRTNodeTypesAndColors() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: currentRealityTreeInput)

        let nodeTypes = Set(try graph.nodes.map { try graph.nodeType(for: $0) })

        #expect(nodeTypes.contains(Notations.CurrentRealityTree.NodeTypes.undesirableEffect), "Should have UndesirableEffect nodes")
        #expect(nodeTypes.contains(Notations.CurrentRealityTree.NodeTypes.intermediateEffect), "Should have IntermediateEffect nodes")
        #expect(nodeTypes.contains(Notations.CurrentRealityTree.NodeTypes.desirableEffect), "Should have DesirableEffect nodes")
        #expect(nodeTypes.contains(Notations.CurrentRealityTree.NodeTypes.given), "Should have Given nodes")
        #expect(nodeTypes.contains(Notations.CurrentRealityTree.NodeTypes.changeable), "Should have Changeable nodes")
        #expect(nodeTypes.contains(Notations.CurrentRealityTree.NodeTypes.andJunctor), "Should have AndJunctor nodes")
    }
}

// MARK: - Future Reality Tree Full Cycle Tests

/// A Future Reality Tree test graph demonstrating solution validation
/// Uses all node types: UndesirableEffect, IntermediateEffect, DesirableEffect, Given, Changeable, AndJunctor
/// (Sufficient-cause logic: multiple unjoined causes are implicitly OR; only AND is an explicit junctor.)
/// Unlike CRT which starts with problems, FRT starts with solutions (Changeable/injections) and builds upward
/// to show how those solutions lead to desirable effects
let futureRealityTreeInput = """
    vgraph salesSolution: FRT "Sales Improvement Plan" {
        // Changeable nodes (injections/solutions we will implement)
        node c1: Changeable "Implement agile product development";
        node c2: Changeable "Hire additional support staff";
        node c3: Changeable "Create customer feedback system";

        // Given (unchangeable facts that still apply)
        node g1: Given "Market is highly competitive";
        node g2: Given "Customer expectations keep rising";

        // Intermediate Effects (expected outcomes from our solutions)
        node ie1: IntermediateEffect "Faster product iterations";
        node ie2: IntermediateEffect "Products match customer needs";
        node ie3: IntermediateEffect "Support response time improves";
        node ie4: IntermediateEffect "Customer feedback drives development";

        // And Junctor (multiple conditions required together for an effect)
        node and1: AndJunctor;

        // Desirable Effects (the goals we want to achieve)
        node de1: DesirableEffect "Sales revenue increasing";
        node de2: DesirableEffect "Customer satisfaction high";
        node de3: DesirableEffect "Market share growing";

        // Some undesirable effects that might still occur (to monitor)
        node ude1: UndesirableEffect "Initial implementation costs";

        // Edges: solutions flow upward to desired outcomes
        // Solutions leading to intermediate effects
        edge c1 -> ie1: changeable_causes_intermediate;
        edge c3 -> ie4: changeable_causes_intermediate;
        edge c2 -> ie3: changeable_causes_intermediate;

        // Given facts combining with solutions
        edge g2 -> and1: given_to_and_junctor;
        edge ie4 -> and1: intermediate_to_and_junctor;

        // And junctor combining conditions
        edge and1 -> ie2: and_junctor_causes_intermediate;

        // Multiple alternative paths to customer satisfaction (implicit OR)
        edge ie2 -> de2: intermediate_causes_desirable;
        edge ie3 -> de2: intermediate_causes_desirable;

        // Intermediate effects leading to desirable effects
        edge ie1 -> de3: intermediate_causes_desirable;
        edge ie2 -> de1: intermediate_causes_desirable;
        edge ie2 -> de3: intermediate_causes_desirable;

        // Acknowledging potential downsides
        edge c1 -> ude1: changeable_causes_undesirable;
        edge c2 -> ude1: changeable_causes_undesirable;

        // Given competitive market affects outcomes
        edge g1 -> ie2: given_causes_intermediate;
    }
    """

@Suite("Future Reality Tree Full Cycle Tests")
struct FutureRealityTreeFullCycleTests {

    @Test
    func parseFRTGraph() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: futureRealityTreeInput)

        // Verify basic structure: 3 Changeable + 2 Given + 4 IE + 1 And + 3 DE + 1 UDE = 14 nodes
        #expect(graph.nodes.count == 14, "Expected 14 nodes")

        #expect(graph.edges.count == 14, "Expected 14 edges")

        let graphId: String = try graph.get(graphAttribute: Attributes.Group.Id)
        #expect(graphId == "salesSolution", "Graph ID should be 'salesSolution'")

        let graphLabel: String = try graph.get(graphAttribute: Attributes.Group.label)
        #expect(graphLabel == "Sales Improvement Plan", "Graph label should be 'Sales Improvement Plan'")

        let notationString: String = graph.notationName
        #expect(notationString == Notations.FutureRealityTree.id.description, "Notation should be FRT")

        let c1 = Node(string: "c1")
        #expect(try graph.nodeType(for: c1) == Notations.FutureRealityTree.NodeTypes.changeable, "c1 should be Changeable type")

        let g1 = Node(string: "g1")
        #expect(try graph.nodeType(for: g1) == Notations.FutureRealityTree.NodeTypes.given, "g1 should be Given type")

        let ie1 = Node(string: "ie1")
        #expect(try graph.nodeType(for: ie1) == Notations.FutureRealityTree.NodeTypes.intermediateEffect, "ie1 should be IntermediateEffect type")

        let de1 = Node(string: "de1")
        #expect(try graph.nodeType(for: de1) == Notations.FutureRealityTree.NodeTypes.desirableEffect, "de1 should be DesirableEffect type")

        let ude1 = Node(string: "ude1")
        #expect(try graph.nodeType(for: ude1) == Notations.FutureRealityTree.NodeTypes.undesirableEffect, "ude1 should be UndesirableEffect type")

        let and1 = Node(string: "and1")
        #expect(try graph.nodeType(for: and1) == Notations.FutureRealityTree.NodeTypes.andJunctor, "and1 should be AndJunctor type")

        try graph.ensure(node: c1, attribute: Attributes.Node.label, isSameAs: "Implement agile product development")
        try graph.ensure(node: de1, attribute: Attributes.Node.label, isSameAs: "Sales revenue increasing")
        try graph.ensure(node: g1, attribute: Attributes.Node.label, isSameAs: "Market is highly competitive")

        let edgeChangeableToIntermediate = graph.edges.first { $0.from == c1 && $0.to == ie1 }
        #expect(edgeChangeableToIntermediate != nil, "Edge from changeable to intermediate should exist")
        if let edge = edgeChangeableToIntermediate {
            #expect(
                try graph.edgeType(for: edge.id) == Notations.FutureRealityTree.EdgeTypes.changeableCausesIntermediate,
                "Edge should be changeable_causes_intermediate type"
            )
        }

        let ie2 = Node(string: "ie2")
        let edgeAndJunctorToIntermediate = graph.edges.first { $0.from == and1 && $0.to == ie2 }
        #expect(edgeAndJunctorToIntermediate != nil, "Edge from AndJunctor to IntermediateEffect should exist")
        if let edge = edgeAndJunctorToIntermediate {
            #expect(
                try graph.edgeType(for: edge.id) == Notations.FutureRealityTree.EdgeTypes.andJunctorCausesIntermediate,
                "Edge should be and_junctor_causes_intermediate type"
            )
        }
    }

    @Test
    func testFRTCompleteGraphEquality() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        let g1 = try parser.parse(source: futureRealityTreeInput)

        let exporter = VGLExporter()
        let exportedGraph = try exporter.export(graph: g1)

        let g2 = try parser.parse(source: exportedGraph)

        try assertGraphsAreEqual(g1, g2)
    }

    @Test
    func exportFRTToDotFormat() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: futureRealityTreeInput)

        let exporter = DotExporter()
        let dotOutput = try exporter.export(graph: graph)

        #expect(dotOutput.hasPrefix("digraph"), "DOT should start with digraph")
        #expect(dotOutput.contains("c1"), "DOT should contain changeable nodes")
        #expect(dotOutput.contains("g1"), "DOT should contain given nodes")
        #expect(dotOutput.contains("ie1"), "DOT should contain intermediate effect nodes")
        #expect(dotOutput.contains("de1"), "DOT should contain desirable effect nodes")
        #expect(dotOutput.contains("ude1"), "DOT should contain undesirable effect nodes")
        #expect(dotOutput.contains("and1"), "DOT should contain and junctor nodes")
    }

    @Test
    func fullCycleParseAndExportFRT() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: futureRealityTreeInput)

        let exporter = VGLExporter()
        let exportedVGraph = try exporter.export(graph: graph)

        #expect(!exportedVGraph.isEmpty, "Exported VGL should not be empty")
        #expect(exportedVGraph.contains("vgraph salesSolution: FRT"), "Exported VGL should contain graph declaration")
        #expect(exportedVGraph.contains("node c1: Changeable"), "Exported VGL should contain changeable nodes")
        #expect(exportedVGraph.contains("node g1: Given"), "Exported VGL should contain given nodes")
        #expect(exportedVGraph.contains("node ie1: IntermediateEffect"), "Exported VGL should contain intermediate effect nodes")
        #expect(exportedVGraph.contains("node de1: DesirableEffect"), "Exported VGL should contain desirable effect nodes")
        #expect(exportedVGraph.contains("node ude1: UndesirableEffect"), "Exported VGL should contain undesirable effect nodes")
        #expect(exportedVGraph.contains("node and1: AndJunctor"), "Exported VGL should contain and junctor nodes")
        #expect(exportedVGraph.contains("edge"), "Exported VGL should contain edges")

        let graph2 = try parser.parse(source: exportedVGraph)

        #expect(graph2.nodes.count == graph.nodes.count, "Node count should be preserved")
        #expect(graph2.edges.count == graph.edges.count, "Edge count should be preserved")

        let graphId1: String = try graph.get(graphAttribute: Attributes.Group.Id)
        let graphId2: String = try graph2.get(graphAttribute: Attributes.Group.Id)
        #expect(graphId1 == graphId2, "Graph ID should be preserved")

        let graphLabel1: String = try graph.get(graphAttribute: Attributes.Group.label)
        let graphLabel2: String = try graph2.get(graphAttribute: Attributes.Group.label)
        #expect(graphLabel1 == graphLabel2, "Graph label should be preserved")

        let notationString1: String = graph.notationName
        let notationString2: String = graph2.notationName
        #expect(notationString1 == notationString2, "Notation should be preserved")

        let c1 = Node(string: "c1")
        let c1Label1: String = try graph.get(node: c1, attribute: Attributes.Node.label)
        let c1Label2: String = try graph2.get(node: c1, attribute: Attributes.Node.label)
        #expect(c1Label1 == c1Label2, "Node labels should be preserved")
    }

    @Test
    func verifyFRTNodeTypesAndColors() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: futureRealityTreeInput)

        let nodeTypes = Set(try graph.nodes.map { try graph.nodeType(for: $0) })

        #expect(nodeTypes.contains(Notations.FutureRealityTree.NodeTypes.changeable), "Should have Changeable nodes")
        #expect(nodeTypes.contains(Notations.FutureRealityTree.NodeTypes.given), "Should have Given nodes")
        #expect(nodeTypes.contains(Notations.FutureRealityTree.NodeTypes.intermediateEffect), "Should have IntermediateEffect nodes")
        #expect(nodeTypes.contains(Notations.FutureRealityTree.NodeTypes.desirableEffect), "Should have DesirableEffect nodes")
        #expect(nodeTypes.contains(Notations.FutureRealityTree.NodeTypes.undesirableEffect), "Should have UndesirableEffect nodes")
        #expect(nodeTypes.contains(Notations.FutureRealityTree.NodeTypes.andJunctor), "Should have AndJunctor nodes")
    }
}

// MARK: - Prerequisite Tree Full Cycle Tests

/// A Prerequisite Tree test graph demonstrating planning with necessary condition thinking
/// Uses all node types: Objective, Obstacle, IntermediateObjective, OR
/// PRT starts with the desired objective and works backward to identify obstacles
/// and intermediate objectives needed to overcome them
let prerequisiteTreeInput = """
    vgraph projectLaunch: PRT "New Product Launch Planning" {
        // The main objective we want to achieve
        node obj1: Objective "Successfully launch product by Q3";

        // Obstacles blocking the main objective
        node obs1: Obstacle "Development team lacks required skills";
        node obs2: Obstacle "Marketing budget not approved";
        node obs3: Obstacle "No distribution channel established";

        // Intermediate objectives to overcome obstacles
        node io1: IntermediateObjective "Train team on new technology";
        node io2: IntermediateObjective "Hire experienced developers";
        node io3: IntermediateObjective "Present ROI analysis to leadership";
        node io4: IntermediateObjective "Partner with existing retailer";
        node io5: IntermediateObjective "Build direct-to-consumer channel";

        // OR junctor for alternative paths
        node or1: OR;
        node or2: OR;

        // Further obstacles blocking intermediate objectives
        node obs4: Obstacle "Training budget limited";
        node obs5: Obstacle "Talent pool is competitive";

        // Edges: obstacles block objectives, intermediate objectives overcome obstacles
        // Main obstacles blocking the objective
        edge obs1 -> obj1: obstacle_blocks_objective;
        edge obs2 -> obj1: obstacle_blocks_objective;
        edge obs3 -> obj1: obstacle_blocks_objective;

        // Intermediate objectives that can overcome skill obstacle (alternatives via OR)
        edge io1 -> or1: intermediate_objective_to_or;
        edge io2 -> or1: intermediate_objective_to_or;
        edge or1 -> obs1: or_to_obstacle;

        // Budget obstacle overcome by ROI analysis
        edge io3 -> obs2: intermediate_objective_overcomes_obstacle;

        // Distribution obstacle has alternative solutions
        edge io4 -> or2: intermediate_objective_to_or;
        edge io5 -> or2: intermediate_objective_to_or;
        edge or2 -> obs3: or_to_obstacle;

        // Further obstacles blocking intermediate objectives (recursive)
        edge obs4 -> io1: obstacle_blocks_intermediate_objective;
        edge obs5 -> io2: obstacle_blocks_intermediate_objective;
    }
    """

@Suite("Prerequisite Tree Full Cycle Tests")
struct PrerequisiteTreeFullCycleTests {

    @Test
    func parsePRTGraph() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: prerequisiteTreeInput)

        // Verify basic structure: 1 Objective + 5 Obstacles + 5 IntermediateObjective + 2 OR = 13 nodes
        #expect(graph.nodes.count == 13, "Expected 13 nodes")

        #expect(graph.edges.count == 12, "Expected 12 edges")

        let graphId: String = try graph.get(graphAttribute: Attributes.Group.Id)
        #expect(graphId == "projectLaunch", "Graph ID should be 'projectLaunch'")

        let graphLabel: String = try graph.get(graphAttribute: Attributes.Group.label)
        #expect(graphLabel == "New Product Launch Planning", "Graph label should be 'New Product Launch Planning'")

        let notationString: String = graph.notationName
        #expect(notationString == Notations.PrerequisiteTree.id.description, "Notation should be PRT")

        let obj1 = Node(string: "obj1")
        #expect(try graph.nodeType(for: obj1) == Notations.PrerequisiteTree.NodeTypes.objective, "obj1 should be Objective type")

        let obs1 = Node(string: "obs1")
        #expect(try graph.nodeType(for: obs1) == Notations.PrerequisiteTree.NodeTypes.obstacle, "obs1 should be Obstacle type")

        let io1 = Node(string: "io1")
        #expect(
            try graph.nodeType(for: io1) == Notations.PrerequisiteTree.NodeTypes.intermediateObjective, "io1 should be IntermediateObjective type")

        let or1 = Node(string: "or1")
        #expect(try graph.nodeType(for: or1) == Notations.PrerequisiteTree.NodeTypes.orJunctor, "or1 should be OR type")

        try graph.ensure(node: obj1, attribute: Attributes.Node.label, isSameAs: "Successfully launch product by Q3")
        try graph.ensure(node: obs1, attribute: Attributes.Node.label, isSameAs: "Development team lacks required skills")
        try graph.ensure(node: io1, attribute: Attributes.Node.label, isSameAs: "Train team on new technology")

        let edgeObstacleToObjective = graph.edges.first { $0.from == obs1 && $0.to == obj1 }
        #expect(edgeObstacleToObjective != nil, "Edge from obstacle to objective should exist")
        if let edge = edgeObstacleToObjective {
            #expect(
                try graph.edgeType(for: edge.id) == Notations.PrerequisiteTree.EdgeTypes.obstacleBlocksObjective,
                "Edge should be obstacle_blocks_objective type"
            )
        }

        let obs2 = Node(string: "obs2")
        let io3 = Node(string: "io3")
        let edgeIntermediateToObstacle = graph.edges.first { $0.from == io3 && $0.to == obs2 }
        #expect(edgeIntermediateToObstacle != nil, "Edge from intermediate objective to obstacle should exist")
        if let edge = edgeIntermediateToObstacle {
            #expect(
                try graph.edgeType(for: edge.id) == Notations.PrerequisiteTree.EdgeTypes.intermediateObjectiveOvercomesObstacle,
                "Edge should be intermediate_objective_overcomes_obstacle type"
            )
        }

        let edgeOrToObstacle = graph.edges.first { $0.from == or1 && $0.to == obs1 }
        #expect(edgeOrToObstacle != nil, "Edge from OR to obstacle should exist")
        if let edge = edgeOrToObstacle {
            #expect(
                try graph.edgeType(for: edge.id) == Notations.PrerequisiteTree.EdgeTypes.orToObstacle,
                "Edge should be or_to_obstacle type"
            )
        }
    }

    @Test
    func testPRTCompleteGraphEquality() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        let g1 = try parser.parse(source: prerequisiteTreeInput)

        let exporter = VGLExporter()
        let exportedGraph = try exporter.export(graph: g1)

        let g2 = try parser.parse(source: exportedGraph)

        try assertGraphsAreEqual(g1, g2)
    }

    @Test
    func exportPRTToDotFormat() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: prerequisiteTreeInput)

        let exporter = DotExporter()
        let dotOutput = try exporter.export(graph: graph)

        #expect(dotOutput.hasPrefix("digraph"), "DOT should start with digraph")
        #expect(dotOutput.contains("obj1"), "DOT should contain objective nodes")
        #expect(dotOutput.contains("obs1"), "DOT should contain obstacle nodes")
        #expect(dotOutput.contains("io1"), "DOT should contain intermediate objective nodes")
        #expect(dotOutput.contains("or1"), "DOT should contain OR junctor nodes")
    }

    @Test
    func fullCycleParseAndExportPRT() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: prerequisiteTreeInput)

        let exporter = VGLExporter()
        let exportedVGraph = try exporter.export(graph: graph)

        #expect(!exportedVGraph.isEmpty, "Exported VGL should not be empty")
        #expect(exportedVGraph.contains("vgraph projectLaunch: PRT"), "Exported VGL should contain graph declaration")
        #expect(exportedVGraph.contains("node obj1: Objective"), "Exported VGL should contain objective nodes")
        #expect(exportedVGraph.contains("node obs1: Obstacle"), "Exported VGL should contain obstacle nodes")
        #expect(exportedVGraph.contains("node io1: IntermediateObjective"), "Exported VGL should contain intermediate objective nodes")
        #expect(exportedVGraph.contains("node or1: OR"), "Exported VGL should contain OR junctor nodes")
        #expect(exportedVGraph.contains("edge"), "Exported VGL should contain edges")

        let graph2 = try parser.parse(source: exportedVGraph)

        #expect(graph2.nodes.count == graph.nodes.count, "Node count should be preserved")
        #expect(graph2.edges.count == graph.edges.count, "Edge count should be preserved")

        let graphId1: String = try graph.get(graphAttribute: Attributes.Group.Id)
        let graphId2: String = try graph2.get(graphAttribute: Attributes.Group.Id)
        #expect(graphId1 == graphId2, "Graph ID should be preserved")

        let graphLabel1: String = try graph.get(graphAttribute: Attributes.Group.label)
        let graphLabel2: String = try graph2.get(graphAttribute: Attributes.Group.label)
        #expect(graphLabel1 == graphLabel2, "Graph label should be preserved")

        let notationString1: String = graph.notationName
        let notationString2: String = graph2.notationName
        #expect(notationString1 == notationString2, "Notation should be preserved")

        let obj1 = Node(string: "obj1")
        let obj1Label1: String = try graph.get(node: obj1, attribute: Attributes.Node.label)
        let obj1Label2: String = try graph2.get(node: obj1, attribute: Attributes.Node.label)
        #expect(obj1Label1 == obj1Label2, "Node labels should be preserved")
    }

    @Test
    func verifyPRTNodeTypesAndColors() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: prerequisiteTreeInput)

        let nodeTypes = Set(try graph.nodes.map { try graph.nodeType(for: $0) })

        #expect(nodeTypes.contains(Notations.PrerequisiteTree.NodeTypes.objective), "Should have Objective nodes")
        #expect(nodeTypes.contains(Notations.PrerequisiteTree.NodeTypes.obstacle), "Should have Obstacle nodes")
        #expect(nodeTypes.contains(Notations.PrerequisiteTree.NodeTypes.intermediateObjective), "Should have IntermediateObjective nodes")
        #expect(nodeTypes.contains(Notations.PrerequisiteTree.NodeTypes.orJunctor), "Should have OR junctor nodes")
    }
}

// MARK: - Evaporating Cloud (EC) Full Cycle Tests

/// An Evaporating Cloud test graph demonstrating conflict resolution
/// Uses all node types: CommonObjective, Need, Want, Conflict, OrJunctor, Assumption, Solution
/// EC answers "What is the conflict and how can we resolve it?" using necessary condition logic.
/// (Multiple inputs are implicitly AND under necessary-condition logic; OR is the explicit junctor for alternative paths.)
/// Left-to-right layout: Common Objective on left, Conflict on right
let evaporatingCloudInput = """
    vgraph projectConflict: EC "Project Delivery vs Quality" {
        // The shared objective both sides agree on
        node obj: CommonObjective "Deliver a successful software product";

        // The two competing needs
        node needA: Need "Meet the market window deadline";
        node needB: Need "Ensure product quality and reliability";

        // The specific wants derived from each need
        node wantA: Want "Release with current feature set now";
        node wantB: Want "Extend timeline for thorough testing";

        // The conflict between the two wants
        node conf: Conflict;

        // Or junctor — alternative necessary inputs
        node or1: OrJunctor;

        // Assumptions underlying the conflict
        node assA: Assumption "Testing always requires calendar time";
        node assB: Assumption "Features cannot be descoped";
        node assC: Assumption "Quality requires full manual testing";

        // Solution that breaks the conflict
        node sol: Solution "Implement automated testing pipeline to achieve quality within deadline";

        // Objective requires both needs (necessary condition)
        edge obj -> needA: objective_to_need;
        edge obj -> needB: objective_to_need;

        // Needs lead to wants
        edge needA -> wantA: need_to_want;
        edge needB -> wantB: need_to_want;

        // Wants create the conflict
        edge wantA -> conf: want_to_conflict;
        edge wantB -> conf: want_to_conflict;

        // Assumptions exposed on the conflict edges
        edge needA -> assA: need_to_assumption;
        edge needB -> assC: need_to_assumption;
        edge conf -> assB: conflict_to_assumption;

        // Solution resolves by breaking assumption
        edge needB -> sol: need_to_solution;
    }
    """

@Suite("Evaporating Cloud Full Cycle Tests")
struct EvaporatingCloudFullCycleTests {

    @Test
    func parseECGraph() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: evaporatingCloudInput)

        // Verify basic structure: 1 Obj + 2 Need + 2 Want + 1 Conflict + 1 Or + 3 Assumption + 1 Solution = 11 nodes
        #expect(graph.nodes.count == 11, "Expected 11 nodes")

        #expect(graph.edges.count == 10, "Expected 10 edges")

        let graphId: String = try graph.get(graphAttribute: Attributes.Group.Id)
        #expect(graphId == "projectConflict", "Graph ID should be 'projectConflict'")

        let graphLabel: String = try graph.get(graphAttribute: Attributes.Group.label)
        #expect(graphLabel == "Project Delivery vs Quality", "Graph label should match")

        let notationString: String = graph.notationName
        #expect(notationString == Notations.EvaporatingCloud.id.description, "Notation should be EC")

        let obj = Node(string: "obj")
        #expect(
            try graph.nodeType(for: obj) == Notations.EvaporatingCloud.NodeTypes.commonObjective,
            "obj should be CommonObjective type")

        let needA = Node(string: "needA")
        #expect(
            try graph.nodeType(for: needA) == Notations.EvaporatingCloud.NodeTypes.need,
            "needA should be Need type")

        let wantA = Node(string: "wantA")
        #expect(
            try graph.nodeType(for: wantA) == Notations.EvaporatingCloud.NodeTypes.want,
            "wantA should be Want type")

        let conf = Node(string: "conf")
        #expect(
            try graph.nodeType(for: conf) == Notations.EvaporatingCloud.NodeTypes.conflict,
            "conf should be Conflict type")

        let or1 = Node(string: "or1")
        #expect(
            try graph.nodeType(for: or1) == Notations.EvaporatingCloud.NodeTypes.orJunctor,
            "or1 should be OrJunctor type")

        let assA = Node(string: "assA")
        #expect(
            try graph.nodeType(for: assA) == Notations.EvaporatingCloud.NodeTypes.assumption,
            "assA should be Assumption type")

        let sol = Node(string: "sol")
        #expect(
            try graph.nodeType(for: sol) == Notations.EvaporatingCloud.NodeTypes.solution,
            "sol should be Solution type")

        try graph.ensure(node: obj, attribute: Attributes.Node.label, isSameAs: "Deliver a successful software product")
        try graph.ensure(node: needA, attribute: Attributes.Node.label, isSameAs: "Meet the market window deadline")

        let edgeObjToNeed = graph.edges.first { $0.from == obj && $0.to == needA }
        #expect(edgeObjToNeed != nil, "Edge from objective to need should exist")
        if let edge = edgeObjToNeed {
            #expect(
                try graph.edgeType(for: edge.id) == Notations.EvaporatingCloud.EdgeTypes.objectiveToNeed,
                "Edge should be objective_to_need type"
            )
        }

        let edgeWantToConflict = graph.edges.first { $0.from == wantA && $0.to == conf }
        #expect(edgeWantToConflict != nil, "Edge from want to conflict should exist")
        if let edge = edgeWantToConflict {
            #expect(
                try graph.edgeType(for: edge.id) == Notations.EvaporatingCloud.EdgeTypes.wantToConflict,
                "Edge should be want_to_conflict type"
            )
        }

        let edgeNeedToAssumption = graph.edges.first { $0.from == needA && $0.to == assA }
        #expect(edgeNeedToAssumption != nil, "Edge from need to assumption should exist")
        if let edge = edgeNeedToAssumption {
            #expect(
                try graph.edgeType(for: edge.id) == Notations.EvaporatingCloud.EdgeTypes.needToAssumption,
                "Edge should be need_to_assumption type"
            )
        }
    }

    @Test
    func testECCompleteGraphEquality() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        let g1 = try parser.parse(source: evaporatingCloudInput)

        let exporter = VGLExporter()
        let exportedGraph = try exporter.export(graph: g1)

        let g2 = try parser.parse(source: exportedGraph)

        try assertGraphsAreEqual(g1, g2)
    }

    @Test
    func exportECToDotFormat() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: evaporatingCloudInput)

        let exporter = DotExporter()
        let dotOutput = try exporter.export(graph: graph)

        #expect(dotOutput.hasPrefix("digraph"), "DOT should start with digraph")
        #expect(dotOutput.contains("obj"), "DOT should contain objective nodes")
        #expect(dotOutput.contains("needA"), "DOT should contain need nodes")
        #expect(dotOutput.contains("wantA"), "DOT should contain want nodes")
        #expect(dotOutput.contains("conf"), "DOT should contain conflict nodes")
        #expect(dotOutput.contains("assA"), "DOT should contain assumption nodes")
        #expect(dotOutput.contains("sol"), "DOT should contain solution nodes")
    }

    @Test
    func fullCycleParseAndExportEC() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: evaporatingCloudInput)

        let exporter = VGLExporter()
        let exportedVGraph = try exporter.export(graph: graph)

        #expect(!exportedVGraph.isEmpty, "Exported VGL should not be empty")
        #expect(exportedVGraph.contains("vgraph projectConflict: EC"), "Exported VGL should contain graph declaration")
        #expect(exportedVGraph.contains("node obj: CommonObjective"), "Exported VGL should contain objective nodes")
        #expect(exportedVGraph.contains("node needA: Need"), "Exported VGL should contain need nodes")
        #expect(exportedVGraph.contains("node wantA: Want"), "Exported VGL should contain want nodes")
        #expect(exportedVGraph.contains("node conf: Conflict"), "Exported VGL should contain conflict nodes")
        #expect(exportedVGraph.contains("node assA: Assumption"), "Exported VGL should contain assumption nodes")
        #expect(exportedVGraph.contains("node sol: Solution"), "Exported VGL should contain solution nodes")
        #expect(exportedVGraph.contains("edge"), "Exported VGL should contain edges")

        let graph2 = try parser.parse(source: exportedVGraph)

        #expect(graph2.nodes.count == graph.nodes.count, "Node count should be preserved")
        #expect(graph2.edges.count == graph.edges.count, "Edge count should be preserved")

        let graphId1: String = try graph.get(graphAttribute: Attributes.Group.Id)
        let graphId2: String = try graph2.get(graphAttribute: Attributes.Group.Id)
        #expect(graphId1 == graphId2, "Graph ID should be preserved")

        let graphLabel1: String = try graph.get(graphAttribute: Attributes.Group.label)
        let graphLabel2: String = try graph2.get(graphAttribute: Attributes.Group.label)
        #expect(graphLabel1 == graphLabel2, "Graph label should be preserved")

        let notationString1: String = graph.notationName
        let notationString2: String = graph2.notationName
        #expect(notationString1 == notationString2, "Notation should be preserved")

        let obj = Node(string: "obj")
        let objLabel1: String = try graph.get(node: obj, attribute: Attributes.Node.label)
        let objLabel2: String = try graph2.get(node: obj, attribute: Attributes.Node.label)
        #expect(objLabel1 == objLabel2, "Node labels should be preserved")
    }

    @Test
    func verifyECNodeTypesAndColors() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: evaporatingCloudInput)

        let nodeTypes = Set(try graph.nodes.map { try graph.nodeType(for: $0) })

        #expect(nodeTypes.contains(Notations.EvaporatingCloud.NodeTypes.commonObjective), "Should have CommonObjective nodes")
        #expect(nodeTypes.contains(Notations.EvaporatingCloud.NodeTypes.need), "Should have Need nodes")
        #expect(nodeTypes.contains(Notations.EvaporatingCloud.NodeTypes.want), "Should have Want nodes")
        #expect(nodeTypes.contains(Notations.EvaporatingCloud.NodeTypes.conflict), "Should have Conflict nodes")
        #expect(nodeTypes.contains(Notations.EvaporatingCloud.NodeTypes.orJunctor), "Should have OrJunctor nodes")
        #expect(nodeTypes.contains(Notations.EvaporatingCloud.NodeTypes.assumption), "Should have Assumption nodes")
        #expect(nodeTypes.contains(Notations.EvaporatingCloud.NodeTypes.solution), "Should have Solution nodes")
    }
}

// MARK: - Transition Tree (TRT) Tests

/// A Transition Tree test graph demonstrating step-by-step implementation planning
/// Uses all node types: UndesirableEffect, IntermediateEffect, DesirableEffect, Given, Changeable, AndJunctor
/// TRT answers "HOW TO CAUSE the change?" by providing detailed action steps
/// All nodes are connected in a complete flow from actions to goals
let transitionTreeInput = """
    vgraph agileTransition: TRT "Agile Transformation Implementation" {
        // Given conditions (the context we're working within)
        node g1: Given "Company has 5 development teams";
        node g2: Given "Current waterfall process causes delays";

        // Changeable causes (actions we will take)
        node c1: Changeable "Introduce daily standups";
        node c2: Changeable "Implement CI/CD pipeline";
        node c3: Changeable "Create cross-functional teams";
        node c4: Changeable "Train teams on Scrum practices";

        // Intermediate effects (stepping stones from actions)
        node ie1: IntermediateEffect "Teams communicate more frequently";
        node ie2: IntermediateEffect "Code integration happens daily";
        node ie3: IntermediateEffect "Teams have diverse skillsets";
        node ie4: IntermediateEffect "Teams follow iterative process";
        node ie5: IntermediateEffect "Silos are broken down";

        // And junctors for combined conditions
        node and1: AndJunctor;
        node and2: AndJunctor;

        // Desirable effects (the goals we achieve)
        node de1: DesirableEffect "Faster time to market";
        node de2: DesirableEffect "Higher quality releases";
        node de3: DesirableEffect "Better team collaboration";

        // Actions lead to intermediate effects
        edge c1 -> ie1: changeable_causes_intermediate;
        edge c2 -> ie2: changeable_causes_intermediate;
        edge c3 -> ie3: changeable_causes_intermediate;
        edge c4 -> ie4: changeable_causes_intermediate;

        // Given context combines with cross-functional teams
        edge g1 -> and1: given_to_and_junctor;
        edge ie3 -> and1: intermediate_to_and_junctor;
        edge and1 -> ie5: and_junctor_causes_intermediate;

        // Breaking silos leads to collaboration
        edge ie5 -> de3: intermediate_causes_desirable;

        // Communication helps collaboration too
        edge ie1 -> de3: intermediate_causes_desirable;

        // CI/CD + iterative process combine for quality
        edge ie2 -> and2: intermediate_to_and_junctor;
        edge ie4 -> and2: intermediate_to_and_junctor;
        edge and2 -> de2: and_junctor_causes_desirable;

        // Quality and collaboration lead to speed
        edge de2 -> de1: desirable_causes_desirable;
        edge de3 -> de1: desirable_causes_desirable;

        // Given waterfall context is addressed by iterative process
        edge g2 -> ie4: given_causes_intermediate;
    }
    """

@Suite("Transition Tree Full Cycle Tests")
struct TransitionTreeFullCycleTests {

    @Test
    func parseTRTGraph() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: transitionTreeInput)

        // Verify basic structure: 2 Given + 4 Changeable + 5 IE + 2 And + 3 DE = 16 nodes
        #expect(graph.nodes.count == 16, "Expected 16 nodes")

        #expect(graph.edges.count == 15, "Expected 15 edges")

        let graphId: String = try graph.get(graphAttribute: Attributes.Group.Id)
        #expect(graphId == "agileTransition", "Graph ID should be 'agileTransition'")

        let graphLabel: String = try graph.get(graphAttribute: Attributes.Group.label)
        #expect(graphLabel == "Agile Transformation Implementation", "Graph label should be 'Agile Transformation Implementation'")

        let notationString: String = graph.notationName
        #expect(notationString == Notations.TransitionTree.id.description, "Notation should be TRT")

        let g1 = Node(string: "g1")
        #expect(try graph.nodeType(for: g1) == Notations.TransitionTree.NodeTypes.given, "g1 should be Given type")

        let c1 = Node(string: "c1")
        #expect(try graph.nodeType(for: c1) == Notations.TransitionTree.NodeTypes.changeable, "c1 should be Changeable type")

        let ie1 = Node(string: "ie1")
        #expect(try graph.nodeType(for: ie1) == Notations.TransitionTree.NodeTypes.intermediateEffect, "ie1 should be IntermediateEffect type")

        let and1 = Node(string: "and1")
        #expect(try graph.nodeType(for: and1) == Notations.TransitionTree.NodeTypes.andJunctor, "and1 should be AndJunctor type")

        let de1 = Node(string: "de1")
        #expect(try graph.nodeType(for: de1) == Notations.TransitionTree.NodeTypes.desirableEffect, "de1 should be DesirableEffect type")

        try graph.ensure(node: g1, attribute: Attributes.Node.label, isSameAs: "Company has 5 development teams")
        try graph.ensure(node: c1, attribute: Attributes.Node.label, isSameAs: "Introduce daily standups")
        try graph.ensure(node: de1, attribute: Attributes.Node.label, isSameAs: "Faster time to market")

        let edgeChangeableToIntermediate = graph.edges.first { $0.from == c1 && $0.to == ie1 }
        #expect(edgeChangeableToIntermediate != nil, "Edge from changeable to intermediate should exist")
        if let edge = edgeChangeableToIntermediate {
            #expect(
                try graph.edgeType(for: edge.id) == Notations.TransitionTree.EdgeTypes.changeableCausesIntermediate,
                "Edge should be changeable_causes_intermediate type"
            )
        }

        let edgeAndToDesirable = graph.edges.first { $0.from == Node(string: "and2") && $0.to == Node(string: "de2") }
        #expect(edgeAndToDesirable != nil, "Edge from and junctor to desirable should exist")
        if let edge = edgeAndToDesirable {
            #expect(
                try graph.edgeType(for: edge.id) == Notations.TransitionTree.EdgeTypes.andJunctorCausesDesirable,
                "Edge should be and_junctor_causes_desirable type"
            )
        }
    }

    @Test
    func testTRTCompleteGraphEquality() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        let g1 = try parser.parse(source: transitionTreeInput)

        let exporter = VGLExporter()
        let exportedGraph = try exporter.export(graph: g1)

        let g2 = try parser.parse(source: exportedGraph)

        try assertGraphsAreEqual(g1, g2)
    }

    @Test
    func exportTRTToDotFormat() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: transitionTreeInput)

        let exporter = DotExporter()
        let dotOutput = try exporter.export(graph: graph)

        #expect(dotOutput.hasPrefix("digraph"), "DOT should start with digraph")
        #expect(dotOutput.contains("g1"), "DOT should contain given nodes")
        #expect(dotOutput.contains("c1"), "DOT should contain changeable nodes")
        #expect(dotOutput.contains("ie1"), "DOT should contain intermediate effect nodes")
        #expect(dotOutput.contains("de1"), "DOT should contain desirable effect nodes")
        #expect(dotOutput.contains("and1"), "DOT should contain and junctor nodes")
    }

    @Test
    func fullCycleParseAndExportTRT() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: transitionTreeInput)

        let exporter = VGLExporter()
        let exportedVGraph = try exporter.export(graph: graph)

        #expect(!exportedVGraph.isEmpty, "Exported VGL should not be empty")
        #expect(exportedVGraph.contains("vgraph agileTransition: TRT"), "Exported VGL should contain graph declaration")
        #expect(exportedVGraph.contains("node g1: Given"), "Exported VGL should contain given nodes")
        #expect(exportedVGraph.contains("node c1: Changeable"), "Exported VGL should contain changeable nodes")
        #expect(exportedVGraph.contains("node ie1: IntermediateEffect"), "Exported VGL should contain intermediate effect nodes")
        #expect(exportedVGraph.contains("node de1: DesirableEffect"), "Exported VGL should contain desirable effect nodes")
        #expect(exportedVGraph.contains("node and1: AndJunctor"), "Exported VGL should contain and junctor nodes")
        #expect(exportedVGraph.contains("edge"), "Exported VGL should contain edges")

        let graph2 = try parser.parse(source: exportedVGraph)

        #expect(graph2.nodes.count == graph.nodes.count, "Node count should be preserved")
        #expect(graph2.edges.count == graph.edges.count, "Edge count should be preserved")

        let graphId1: String = try graph.get(graphAttribute: Attributes.Group.Id)
        let graphId2: String = try graph2.get(graphAttribute: Attributes.Group.Id)
        #expect(graphId1 == graphId2, "Graph ID should be preserved")

        let graphLabel1: String = try graph.get(graphAttribute: Attributes.Group.label)
        let graphLabel2: String = try graph2.get(graphAttribute: Attributes.Group.label)
        #expect(graphLabel1 == graphLabel2, "Graph label should be preserved")

        let notationString1: String = graph.notationName
        let notationString2: String = graph2.notationName
        #expect(notationString1 == notationString2, "Notation should be preserved")

        let de1 = Node(string: "de1")
        let de1Label1: String = try graph.get(node: de1, attribute: Attributes.Node.label)
        let de1Label2: String = try graph2.get(node: de1, attribute: Attributes.Node.label)
        #expect(de1Label1 == de1Label2, "Node labels should be preserved")
    }

    @Test
    func verifyTRTNodeTypesAndColors() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: transitionTreeInput)

        // Verify the 5 node types used in this example are present
        // (UndesirableEffect is available in TRT but not used in this planning-focused example)
        let nodeTypes = Set(try graph.nodes.map { try graph.nodeType(for: $0) })

        #expect(nodeTypes.contains(Notations.TransitionTree.NodeTypes.intermediateEffect), "Should have IntermediateEffect nodes")
        #expect(nodeTypes.contains(Notations.TransitionTree.NodeTypes.desirableEffect), "Should have DesirableEffect nodes")
        #expect(nodeTypes.contains(Notations.TransitionTree.NodeTypes.given), "Should have Given nodes")
        #expect(nodeTypes.contains(Notations.TransitionTree.NodeTypes.changeable), "Should have Changeable nodes")
        #expect(nodeTypes.contains(Notations.TransitionTree.NodeTypes.andJunctor), "Should have AndJunctor nodes")
    }
}

// MARK: - Attack-Defense Tree (ADTree) Tests

/// An Attack-Defense Tree test graph demonstrating security modelling
/// Uses all node types: Attack, Defense, AndJunctor
/// Based on the data confidentiality example from Kordy et al. (2014)
/// ADTrees model the interaction between an attacker and a defender
let adTreeInput = """
    vgraph dataConfidentiality: ADTree "Data Confidentiality" {
        // Defense nodes (the defender's goals)
        node dataConf: Defense "Data Confidentiality";
        node networkSec: Defense "Network Security";
        node physicalSec: Defense "Physical Security";
        node accessControl: Defense "Access Control";
        node firewalls: Defense "Firewalls";
        node ids: Defense "IDS";
        node passwords: Defense "Passwords";
        node strongPasswords: Defense "Strong Passwords";
        node lock1: Defense "Lock";
        node screening: Defense "Screening";
        node sensitivityTraining: Defense "Sensitivity Training";
        node securityGuard: Defense "Security Guard";
        node videoCameras: Defense "Video Cameras";

        // Attack nodes (the attacker's goals)
        node employeeAttack: Attack "Employee Attack";
        node breakIn: Attack "Break In";
        node corruption: Attack "Corruption";
        node socialEngineering: Attack "Social Engineering";
        node dictionaryAttack: Attack "Dictionary Attack";
        node strongPasswordAttacks: Attack "Strong Password Attacks";
        node findNote: Attack "Find Note";
        node samePasswordDiffAccount: Attack "Same Password, Different Account";
        node backDoor: Attack "Back Door";
        node fireEscape: Attack "Fire Escape";
        node defeatLock: Attack "Defeat Lock";
        node forceOpen: Attack "Force Open";
        node acquireKeys: Attack "Acquire Keys";
        node defeatGuard: Attack "Defeat Guard";
        node bribe: Attack "Bribe";
        node overpower: Attack "Overpower";
        node stealKeys: Attack "Steal Keys";
        node outnumber: Attack "Outnumber";
        node useWeapons: Attack "Use Weapons";

        // AND junctors for conjunctive refinement
        node andDataConf: AndJunctor;
        node andNetworkSec: AndJunctor;
        node andOverpower: AndJunctor;

        // Defense refinement edges via AND junctors
        edge networkSec -> andDataConf: defense_to_and_junctor;
        edge physicalSec -> andDataConf: defense_to_and_junctor;
        edge andDataConf -> dataConf: and_junctor_to_defense;
        edge accessControl -> andNetworkSec: defense_to_and_junctor;
        edge firewalls -> andNetworkSec: defense_to_and_junctor;
        edge ids -> andNetworkSec: defense_to_and_junctor;
        edge andNetworkSec -> networkSec: and_junctor_to_defense;
        edge passwords -> accessControl: defense_refines_defense;

        // Attack refinement edges (solid)
        edge corruption -> employeeAttack: attack_refines_attack;
        edge socialEngineering -> employeeAttack: attack_refines_attack;
        edge backDoor -> breakIn: attack_refines_attack;
        edge fireEscape -> breakIn: attack_refines_attack;
        edge findNote -> strongPasswordAttacks: attack_refines_attack;
        edge samePasswordDiffAccount -> strongPasswordAttacks: attack_refines_attack;
        edge forceOpen -> defeatLock: attack_refines_attack;
        edge acquireKeys -> defeatLock: attack_refines_attack;
        edge bribe -> defeatGuard: attack_refines_attack;
        edge overpower -> defeatGuard: attack_refines_attack;
        edge stealKeys -> defeatGuard: attack_refines_attack;

        // Countermeasure edges (dotted): defense counters attack
        edge strongPasswords -> dictionaryAttack: defense_counters_attack;
        edge lock1 -> backDoor: defense_counters_attack;
        edge screening -> corruption: defense_counters_attack;
        edge sensitivityTraining -> socialEngineering: defense_counters_attack;
        edge securityGuard -> breakIn: defense_counters_attack;
        edge videoCameras -> defeatGuard: defense_counters_attack;

        // Countermeasure edges (dotted): attack counters defense
        edge employeeAttack -> dataConf: attack_counters_defense;
        edge breakIn -> physicalSec: attack_counters_defense;
        edge dictionaryAttack -> passwords: attack_counters_defense;
        edge strongPasswordAttacks -> strongPasswords: attack_counters_defense;
        edge defeatLock -> lock1: attack_counters_defense;
        edge defeatGuard -> securityGuard: attack_counters_defense;

        // AND junctor edges for conjunctive refinement of Overpower
        edge outnumber -> andOverpower: attack_to_and_junctor;
        edge useWeapons -> andOverpower: attack_to_and_junctor;
        edge andOverpower -> overpower: and_junctor_to_attack;
    }
    """

@Suite("Attack-Defense Tree Full Cycle Tests")
struct ADTreeFullCycleTests {

    @Test
    func parseADTreeGraph() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: adTreeInput)

        // Verify basic structure: 13 defense + 19 attack + 3 AND = 35 nodes
        #expect(graph.nodes.count == 35, "Expected 35 nodes")

        // Count edges: 12 refinement + 12 countermeasure + 10 junctor = 34 edges
        #expect(graph.edges.count == 34, "Expected 34 edges")

        let graphId: String = try graph.get(graphAttribute: Attributes.Group.Id)
        #expect(graphId == "dataConfidentiality", "Graph ID should be 'dataConfidentiality'")

        let graphLabel: String = try graph.get(graphAttribute: Attributes.Group.label)
        #expect(graphLabel == "Data Confidentiality", "Graph label should be 'Data Confidentiality'")

        let notationString: String = graph.notationName
        #expect(notationString == Notations.ADTree.id.description, "Notation should be ADTree")

        let dataConf = Node(string: "dataConf")
        #expect(try graph.nodeType(for: dataConf) == Notations.ADTree.NodeTypes.defense, "dataConf should be Defense type")

        let breakIn = Node(string: "breakIn")
        #expect(try graph.nodeType(for: breakIn) == Notations.ADTree.NodeTypes.attack, "breakIn should be Attack type")

        let andOverpower = Node(string: "andOverpower")
        #expect(try graph.nodeType(for: andOverpower) == Notations.ADTree.NodeTypes.andJunctor, "andOverpower should be AndJunctor type")

        try graph.ensure(node: dataConf, attribute: Attributes.Node.label, isSameAs: "Data Confidentiality")
        try graph.ensure(node: breakIn, attribute: Attributes.Node.label, isSameAs: "Break In")

        let andDataConf = Node(string: "andDataConf")
        #expect(try graph.nodeType(for: andDataConf) == Notations.ADTree.NodeTypes.andJunctor, "andDataConf should be AndJunctor type")

        let edgeDefenseToAnd = graph.edges.first { $0.from == Node(string: "networkSec") && $0.to == andDataConf }
        #expect(edgeDefenseToAnd != nil, "Edge from networkSec to andDataConf should exist")
        if let edge = edgeDefenseToAnd {
            #expect(
                try graph.edgeType(for: edge.id) == Notations.ADTree.EdgeTypes.defenseToAndJunctor,
                "Edge should be defense_to_and_junctor type"
            )
        }

        let edgeAndToDefense = graph.edges.first { $0.from == andDataConf && $0.to == dataConf }
        #expect(edgeAndToDefense != nil, "Edge from andDataConf to dataConf should exist")
        if let edge = edgeAndToDefense {
            #expect(
                try graph.edgeType(for: edge.id) == Notations.ADTree.EdgeTypes.andJunctorToDefense,
                "Edge should be and_junctor_to_defense type"
            )
        }

        let edgeCounterAttack = graph.edges.first { $0.from == Node(string: "employeeAttack") && $0.to == dataConf }
        #expect(edgeCounterAttack != nil, "Edge from employeeAttack to dataConf should exist")
        if let edge = edgeCounterAttack {
            #expect(
                try graph.edgeType(for: edge.id) == Notations.ADTree.EdgeTypes.attackCountersDefense,
                "Edge should be attack_counters_defense type"
            )
        }
    }

    @Test
    func testADTreeCompleteGraphEquality() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        let g1 = try parser.parse(source: adTreeInput)

        let exporter = VGLExporter()
        let exportedGraph = try exporter.export(graph: g1)

        let g2 = try parser.parse(source: exportedGraph)

        try assertGraphsAreEqual(g1, g2)
    }

    @Test
    func exportADTreeToDotFormat() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: adTreeInput)

        let exporter = DotExporter()
        let dotOutput = try exporter.export(graph: graph)

        #expect(dotOutput.hasPrefix("digraph"), "DOT should start with digraph")
        #expect(dotOutput.contains("dataConf"), "DOT should contain defense nodes")
        #expect(dotOutput.contains("breakIn"), "DOT should contain attack nodes")
        #expect(dotOutput.contains("andOverpower"), "DOT should contain AND junctor nodes")
        #expect(dotOutput.contains("andDataConf"), "DOT should contain andDataConf AND junctor node")
    }

    @Test
    func fullCycleParseAndExportADTree() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: adTreeInput)

        let exporter = VGLExporter()
        let exportedVGraph = try exporter.export(graph: graph)

        #expect(!exportedVGraph.isEmpty, "Exported VGL should not be empty")
        #expect(exportedVGraph.contains("vgraph dataConfidentiality: ADTree"), "Exported VGL should contain graph declaration")
        #expect(exportedVGraph.contains("node dataConf: Defense"), "Exported VGL should contain defense nodes")
        #expect(exportedVGraph.contains("node breakIn: Attack"), "Exported VGL should contain attack nodes")
        #expect(exportedVGraph.contains("node andOverpower: AndJunctor"), "Exported VGL should contain AND junctor nodes")
        #expect(exportedVGraph.contains("node andDataConf: AndJunctor"), "Exported VGL should contain andDataConf AND junctor node")
        #expect(exportedVGraph.contains("edge"), "Exported VGL should contain edges")

        let graph2 = try parser.parse(source: exportedVGraph)

        #expect(graph2.nodes.count == graph.nodes.count, "Node count should be preserved")
        #expect(graph2.edges.count == graph.edges.count, "Edge count should be preserved")

        let graphId1: String = try graph.get(graphAttribute: Attributes.Group.Id)
        let graphId2: String = try graph2.get(graphAttribute: Attributes.Group.Id)
        #expect(graphId1 == graphId2, "Graph ID should be preserved")

        let graphLabel1: String = try graph.get(graphAttribute: Attributes.Group.label)
        let graphLabel2: String = try graph2.get(graphAttribute: Attributes.Group.label)
        #expect(graphLabel1 == graphLabel2, "Graph label should be preserved")

        let notationString1: String = graph.notationName
        let notationString2: String = graph2.notationName
        #expect(notationString1 == notationString2, "Notation should be preserved")

        let dataConf = Node(string: "dataConf")
        let dataConfLabel1: String = try graph.get(node: dataConf, attribute: Attributes.Node.label)
        let dataConfLabel2: String = try graph2.get(node: dataConf, attribute: Attributes.Node.label)
        #expect(dataConfLabel1 == dataConfLabel2, "Node labels should be preserved")
    }

    @Test
    func verifyADTreeNodeTypesAndColors() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: adTreeInput)

        let nodeTypes = Set(try graph.nodes.map { try graph.nodeType(for: $0) })

        #expect(nodeTypes.contains(Notations.ADTree.NodeTypes.attack), "Should have Attack nodes")
        #expect(nodeTypes.contains(Notations.ADTree.NodeTypes.defense), "Should have Defense nodes")
        #expect(nodeTypes.contains(Notations.ADTree.NodeTypes.andJunctor), "Should have AndJunctor nodes")
    }
}

// MARK: - Goal Tree (GT) Full Cycle Tests

/// A Goal Tree test graph demonstrating strategic planning with necessity logic
/// Uses all node types: Goal, CriticalSuccessFactor, NecessaryCondition
/// GT answers "What must we achieve to reach our Goal?" using necessary condition logic
/// Top-to-bottom layout: Goal at top, Necessary Conditions expand downward
let goalTreeInput = """
    vgraph companyStrategy: GoalTree "Increase Profitability" {
        // The single system goal
        node goal: Goal "Make more money, now and in the future";

        // Critical Success Factors (3-5 high-level terminal outcomes)
        node csf1: CriticalSuccessFactor "Maximize Throughput";
        node csf2: CriticalSuccessFactor "Control Operating Expense";
        node csf3: CriticalSuccessFactor "Minimize Inventory and Investment";

        // Necessary Conditions supporting CSF1 (Maximize Throughput)
        node nc1: NecessaryCondition "Maximize sales volume";
        node nc2: NecessaryCondition "Minimize variable costs";
        node nc3: NecessaryCondition "Highly appealing products";

        // Necessary Conditions supporting CSF2 (Control Operating Expense)
        node nc4: NecessaryCondition "Minimize scrap and rework";
        node nc5: NecessaryCondition "Optimize overhead";

        // Necessary Conditions supporting CSF3 (Minimize Inventory)
        node nc6: NecessaryCondition "Optimize outgoing supply chain";
        node nc7: NecessaryCondition "Optimize incoming supply chain";

        // Lower-level NCs (sub-NCs supporting higher NCs)
        node nc8: NecessaryCondition "Effective market research";
        node nc9: NecessaryCondition "High-quality products";
        node nc10: NecessaryCondition "Robust production process";

        // CSFs support the Goal
        edge csf1 -> goal: csf_to_goal;
        edge csf2 -> goal: csf_to_goal;
        edge csf3 -> goal: csf_to_goal;

        // NCs support CSFs
        edge nc1 -> csf1: nc_to_csf;
        edge nc2 -> csf1: nc_to_csf;
        edge nc3 -> csf1: nc_to_csf;
        edge nc4 -> csf2: nc_to_csf;
        edge nc5 -> csf2: nc_to_csf;
        edge nc6 -> csf3: nc_to_csf;
        edge nc7 -> csf3: nc_to_csf;

        // Sub-NCs support higher NCs
        edge nc8 -> nc1: nc_to_nc;
        edge nc9 -> nc3: nc_to_nc;
        edge nc10 -> nc4: nc_to_nc;
    }
    """

@Suite("Goal Tree Full Cycle Tests")
struct GoalTreeFullCycleTests {

    @Test
    func parseGoalTreeGraph() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: goalTreeInput)

        // Verify basic structure: 1 Goal + 3 CSF + 10 NC = 14 nodes
        #expect(graph.nodes.count == 14, "Expected 14 nodes")

        // Count edges: 3 csf_to_goal + 7 nc_to_csf + 3 nc_to_nc = 13 edges
        #expect(graph.edges.count == 13, "Expected 13 edges")

        let graphId: String = try graph.get(graphAttribute: Attributes.Group.Id)
        #expect(graphId == "companyStrategy", "Graph ID should be 'companyStrategy'")

        let graphLabel: String = try graph.get(graphAttribute: Attributes.Group.label)
        #expect(graphLabel == "Increase Profitability", "Graph label should be 'Increase Profitability'")

        let notationString: String = graph.notationName
        #expect(notationString == Notations.GoalTree.id.description, "Notation should be GoalTree")

        let goal = Node(string: "goal")
        #expect(try graph.nodeType(for: goal) == Notations.GoalTree.NodeTypes.goal, "goal should be Goal type")

        let csf1 = Node(string: "csf1")
        #expect(try graph.nodeType(for: csf1) == Notations.GoalTree.NodeTypes.criticalSuccessFactor, "csf1 should be CriticalSuccessFactor type")

        let nc1 = Node(string: "nc1")
        #expect(try graph.nodeType(for: nc1) == Notations.GoalTree.NodeTypes.necessaryCondition, "nc1 should be NecessaryCondition type")

        try graph.ensure(node: goal, attribute: Attributes.Node.label, isSameAs: "Make more money, now and in the future")
        try graph.ensure(node: csf1, attribute: Attributes.Node.label, isSameAs: "Maximize Throughput")
        try graph.ensure(node: nc1, attribute: Attributes.Node.label, isSameAs: "Maximize sales volume")

        let edgeCSFToGoal = graph.edges.first { $0.from == csf1 && $0.to == goal }
        #expect(edgeCSFToGoal != nil, "Edge from CSF to Goal should exist")
        if let edge = edgeCSFToGoal {
            #expect(
                try graph.edgeType(for: edge.id) == Notations.GoalTree.EdgeTypes.csfToGoal,
                "Edge should be csf_to_goal type"
            )
        }

        let edgeNCToCSF = graph.edges.first { $0.from == nc1 && $0.to == csf1 }
        #expect(edgeNCToCSF != nil, "Edge from NC to CSF should exist")
        if let edge = edgeNCToCSF {
            #expect(
                try graph.edgeType(for: edge.id) == Notations.GoalTree.EdgeTypes.ncToCSF,
                "Edge should be nc_to_csf type"
            )
        }

        let nc8 = Node(string: "nc8")
        let edgeNCToNC = graph.edges.first { $0.from == nc8 && $0.to == nc1 }
        #expect(edgeNCToNC != nil, "Edge from sub-NC to NC should exist")
        if let edge = edgeNCToNC {
            #expect(
                try graph.edgeType(for: edge.id) == Notations.GoalTree.EdgeTypes.ncToNC,
                "Edge should be nc_to_nc type"
            )
        }
    }

    @Test
    func testGoalTreeCompleteGraphEquality() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        let g1 = try parser.parse(source: goalTreeInput)

        let exporter = VGLExporter()
        let exportedGraph = try exporter.export(graph: g1)

        let g2 = try parser.parse(source: exportedGraph)

        try assertGraphsAreEqual(g1, g2)
    }

    @Test
    func exportGoalTreeToDotFormat() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: goalTreeInput)

        let exporter = DotExporter()
        let dotOutput = try exporter.export(graph: graph)

        #expect(dotOutput.hasPrefix("digraph"), "DOT should start with digraph")
        #expect(dotOutput.contains("goal"), "DOT should contain goal node")
        #expect(dotOutput.contains("csf1"), "DOT should contain CSF nodes")
        #expect(dotOutput.contains("nc1"), "DOT should contain NC nodes")
    }

    @Test
    func fullCycleParseAndExportGoalTree() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: goalTreeInput)

        let exporter = VGLExporter()
        let exportedVGraph = try exporter.export(graph: graph)

        #expect(!exportedVGraph.isEmpty, "Exported VGL should not be empty")
        #expect(exportedVGraph.contains("vgraph companyStrategy: GoalTree"), "Exported VGL should contain graph declaration")
        #expect(exportedVGraph.contains("node goal: Goal"), "Exported VGL should contain Goal node")
        #expect(exportedVGraph.contains("node csf1: CriticalSuccessFactor"), "Exported VGL should contain CSF nodes")
        #expect(exportedVGraph.contains("node nc1: NecessaryCondition"), "Exported VGL should contain NC nodes")
        #expect(exportedVGraph.contains("edge"), "Exported VGL should contain edges")

        let graph2 = try parser.parse(source: exportedVGraph)

        #expect(graph2.nodes.count == graph.nodes.count, "Node count should be preserved")
        #expect(graph2.edges.count == graph.edges.count, "Edge count should be preserved")

        let graphId1: String = try graph.get(graphAttribute: Attributes.Group.Id)
        let graphId2: String = try graph2.get(graphAttribute: Attributes.Group.Id)
        #expect(graphId1 == graphId2, "Graph ID should be preserved")

        let graphLabel1: String = try graph.get(graphAttribute: Attributes.Group.label)
        let graphLabel2: String = try graph2.get(graphAttribute: Attributes.Group.label)
        #expect(graphLabel1 == graphLabel2, "Graph label should be preserved")

        let notationString1: String = graph.notationName
        let notationString2: String = graph2.notationName
        #expect(notationString1 == notationString2, "Notation should be preserved")

        let goal = Node(string: "goal")
        let goalLabel1: String = try graph.get(node: goal, attribute: Attributes.Node.label)
        let goalLabel2: String = try graph2.get(node: goal, attribute: Attributes.Node.label)
        #expect(goalLabel1 == goalLabel2, "Node labels should be preserved")
    }

    @Test
    func verifyGoalTreeNodeTypesAndColors() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: goalTreeInput)

        let nodeTypes = Set(try graph.nodes.map { try graph.nodeType(for: $0) })

        #expect(nodeTypes.contains(Notations.GoalTree.NodeTypes.goal), "Should have Goal nodes")
        #expect(nodeTypes.contains(Notations.GoalTree.NodeTypes.criticalSuccessFactor), "Should have CriticalSuccessFactor nodes")
        #expect(nodeTypes.contains(Notations.GoalTree.NodeTypes.necessaryCondition), "Should have NecessaryCondition nodes")
    }

    // MARK: - Decision Tree Tests

    let decisionTreeInput = """
        vgraph hiringDecision: DecisionTree "Should We Hire This Candidate?" {
            node q1: DecisionPoint "Is the candidate technically qualified?";
            node c1: Choice "Yes";
            node c2: Choice "No";
            node q2: DecisionPoint "Does the candidate fit the team culture?";
            node c3: Choice "Yes";
            node c4: Choice "No";
            node o1: Outcome "Extend offer";
            node o2: Outcome "Reject — technical skills insufficient";
            node o3: Outcome "Reject — poor cultural fit";

            edge q1 -> c1: decision_to_choice;
            edge q1 -> c2: decision_to_choice;
            edge c1 -> q2: choice_to_decision;
            edge c2 -> o2: choice_to_outcome;
            edge q2 -> c3: decision_to_choice;
            edge q2 -> c4: decision_to_choice;
            edge c3 -> o1: choice_to_outcome;
            edge c4 -> o3: choice_to_outcome;
        }
        """

    @Test
    func fullCycleParseAndExportDecisionTree() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: decisionTreeInput)

        #expect(graph.nodes.count == 9, "Should have 9 nodes")
        #expect(graph.edges.count == 8, "Should have 8 edges")

        let exporter = VGLExporter()
        let exportedVGL = try exporter.export(graph: graph)

        #expect(exportedVGL.contains("vgraph hiringDecision: DecisionTree"), "Should contain graph declaration")
        #expect(exportedVGL.contains("node q1: DecisionPoint"), "Should contain DecisionPoint nodes")
        #expect(exportedVGL.contains("node c1: Choice"), "Should contain Choice nodes")
        #expect(exportedVGL.contains("node o1: Outcome"), "Should contain Outcome nodes")
        #expect(exportedVGL.contains("edge"), "Should contain edges")

        let graph2 = try parser.parse(source: exportedVGL)
        #expect(graph2.nodes.count == graph.nodes.count, "Node count should be preserved")
        #expect(graph2.edges.count == graph.edges.count, "Edge count should be preserved")

        let notationString1: String = graph.notationName
        let notationString2: String = graph2.notationName
        #expect(notationString1 == notationString2, "Notation should be preserved")
    }

    @Test
    func verifyDecisionTreeNodeTypes() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: decisionTreeInput)

        let nodeTypes = Set(try graph.nodes.map { try graph.nodeType(for: $0) })

        #expect(nodeTypes.contains(Notations.DecisionTree.NodeTypes.decisionPoint), "Should have DecisionPoint nodes")
        #expect(nodeTypes.contains(Notations.DecisionTree.NodeTypes.choice), "Should have Choice nodes")
        #expect(nodeTypes.contains(Notations.DecisionTree.NodeTypes.outcome), "Should have Outcome nodes")
    }

    @Test
    func exportDecisionTreeToDotFormat() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: decisionTreeInput)

        let exporter = DotExporter()
        let dotOutput = try exporter.export(graph: graph)

        #expect(dotOutput.hasPrefix("digraph"), "DOT should start with digraph")
        #expect(dotOutput.contains("q1"), "DOT should contain decision point nodes")
        #expect(dotOutput.contains("c1"), "DOT should contain choice nodes")
        #expect(dotOutput.contains("o1"), "DOT should contain outcome nodes")
    }

    /// Each DecisionTree node type exports a distinct gColor so Graphviz-rendered
    /// output (when SVG isn't used) still differentiates node types visually.
    @Test
    func testDecisionTreeGColorsAreDistinct() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: decisionTreeInput)

        let exporter = DotExporter()
        let dotOutput = try exporter.export(graph: graph)

        // Nine nodes across three types, so distinctness is counted per type.
        #expect(Set(dotColors(in: dotOutput)).count == 3, "each node type should export a distinct colour")
    }
}

// MARK: - Notation Registry Tests

struct NotationRegistryTests {

    /// Verifies that the error message for an unknown notation is generated from `notationRegistry`,
    /// not from a separate hardcoded string. Adding a notation only requires one registry entry —
    /// the error message stays in sync automatically.
    @Test
    func testUnknownNotationErrorListsAllRegisteredNotations() throws {
        let capturer = CapturingLogger()
        let parser = VGraphParser(logger: capturer)
        let vgl = """
            vgraph g: UnknownNotation "Test" {}
            """
        // Parsing succeeds structurally but logs an error for the unknown notation
        _ = try parser.parse(source: vgl)

        #expect(capturer.errors.count == 1, "Should log exactly one error for unknown notation")
        let errorMessage = try #require(capturer.errors.first)
        #expect(errorMessage.contains("UnknownNotation"), "Error should echo the bad notation name")

        // Every name in the registry must appear in the error message.
        // This test would fail to compile if notationRegistry didn't exist,
        // and fails at runtime if any registered notation is omitted from the message.
        for entry in NotationRegistry.entries {
            #expect(
                errorMessage.contains(entry.id),
                "Error message should list '\(entry.id)' from NotationRegistry"
            )
        }
    }

    /// Smoke-test: every name in the registry successfully parses a minimal graph.
    @Test(arguments: NotationRegistry.entries.map(\.id))
    func testEveryRegisteredNotationParses(name: String) throws {
        let vgl = "vgraph g: \(name) \"Test\" {}"
        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: vgl)
        let notation: String = graph.notationName
        #expect(notation == name, "\(name) should round-trip through notation attribute")
    }
}

// MARK: - Annotation Extension Tests

struct AnnotationExtensionTests {

    @Test
    func testAnnotationExtensionRoundTrip() throws {
        let input = """
            vgraph annotatedMap: ConceptMap, Annotation "Annotated Concept Map" {
                node c1: Concept "Learning"
                node c2: Concept "Practice"
                node r1: Relation "requires"
                node a1: Annotation "This is key"
                edge c1 -> r1
                edge r1 -> c2
                edge c1 -> a1
            }
            """

        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: input)

        #expect(graph.nodes.count == 4, "Should have 4 nodes")
        #expect(graph.edges.count == 3, "Should have 3 edges")

        #expect(graph.nodeTypes.contains(Notations.Annotation.annotation), "Should have Annotation node type")

        let exporter = VGLExporter()
        let exportedVGL = try exporter.export(graph: graph)
        #expect(exportedVGL.contains("ConceptMap, Annotation"), "Exported header should include extension")
        #expect(exportedVGL.contains("node a1: Annotation"), "Should export Annotation node")
        #expect(exportedVGL.contains("edge"), "Should export edges")

        let graph2 = try parser.parse(source: exportedVGL)
        #expect(graph2.nodes.count == graph.nodes.count, "Node count should be preserved after round-trip")
        #expect(graph2.edges.count == graph.edges.count, "Edge count should be preserved after round-trip")
    }

    @Test
    func testAnnotationEdgesFromAllNodeTypes() throws {
        let input = """
            vgraph cmAnnotated: ConceptMap, Annotation "Test" {
                node c1: Concept "Idea"
                node e1: EmphasizedConcept "Key Idea"
                node r1: Relation "supports"
                node a1: Annotation "Note"
                edge c1 -> r1
                edge r1 -> e1
                edge c1 -> a1
                edge e1 -> a1
                edge r1 -> a1
            }
            """

        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: input)

        // All three concept map node types should be able to connect to Annotation
        #expect(graph.edges.count == 5, "Should have 5 edges (2 concept map + 3 annotation edges)")

        let annotationEdgeTypes = graph.edgeTypes.filter { $0.to == Notations.Annotation.annotation }
        #expect(annotationEdgeTypes.count == 3, "Should have 3 edge types pointing to Annotation (one per CM node type)")
    }

    @Test
    func testNotationAttributePreservedWithExtension() throws {
        let input = """
            vgraph test: ConceptMap, Annotation "Test" {
                node c1: Concept "Idea"
                node a1: Annotation "Note"
                edge c1 -> a1
            }
            """

        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: input)

        let notation: String = graph.notationName
        #expect(notation == "ConceptMap", "Notation attribute should be 'ConceptMap' (without extension)")

        let extensions = graph.notationDefinition.extensions.joined(separator: ",")
        #expect(extensions == "Annotation", "Extensions attribute should be 'Annotation'")
    }

    // MARK: - vnotation tests

    @Test
    func testVNotationPureRoundTrip() throws {
        let input = """
            vnotation RiskMap {
                layout: topToBottom

                node type: Risk    [nodeStyle: iconWithText, color: "#cc3333", icon: "risk"]
                node type: Control [nodeStyle: simpleRoundedText, color: "#339933"]
                node type: Owner   [nodeStyle: circle, color: "#3366cc"]

                edge type: risk_has_control  from: Risk    to: Control
                edge type: control_owned_by  from: Control to: Owner
            }

            vgraph rm1: RiskMap "Project Risk Map" {
                node r1: Risk    "Schedule overrun"
                node c1: Control "Weekly reviews"
                node o1: Owner   "PM"
                edge r1 -> c1
                edge c1 -> o1
            }
            """

        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: input)

        // Node types were registered
        let registeredTypeIds = graph.nodeTypes.map { $0.id }
        #expect(registeredTypeIds.contains("Risk"))
        #expect(registeredTypeIds.contains("Control"))
        #expect(registeredTypeIds.contains("Owner"))

        // Nodes were created
        #expect(graph.nodes.count == 3)

        // Edges were created
        #expect(graph.edges.count == 2)

        // Layout direction was applied
        let layout: String = try graph.get(graphAttribute: Attributes.Group.layoutDirection)
        #expect(layout == "Top to Bottom")
    }

    @Test
    func testVNotationAllNodeStyleVariants() throws {
        let input = """
            vnotation StyleTest {
                node type: N1 [nodeStyle: iconWithText,       color: "#111111", icon: "and"]
                node type: N2 [nodeStyle: simpleRoundedText,  color: "#222222"]
                node type: N3 [nodeStyle: roundedBox,         color: "#333333"]
                node type: N4 [nodeStyle: withCategory,       color: "#444444", category: "CAT"]
                node type: N5 [nodeStyle: withCategoryAndIcon, color: "#555555", category: "X", icon: "circle"]
                node type: N6 [nodeStyle: iconOnly,           icon: "moon"]
                node type: N7 [nodeStyle: circle,             color: "#777777"]
                node type: N8 [nodeStyle: bareText]
                node type: N9 [nodeStyle: hidden]
                node type: N10 [nodeStyle: custom]
            }

            vgraph st1: StyleTest "Style Test Graph" {
                node a: N1 "one"
                node b: N2 "two"
                node c: N3 "three"
                node d: N4 "four"
                node e: N5 "five"
                node f: N6 "six"
                node g: N7 "seven"
                node h: N8 "eight"
                node i: N9 "nine"
                node j: N10 "ten"
            }
            """

        let parser = VGraphParser(logger: NoOpLogger())
        // Should not throw — all nodeStyle values are valid
        let graph = try parser.parse(source: input)
        #expect(graph.nodes.count == 10)
    }

    @Test
    func testVNotationExtendsBuiltin() throws {
        let input = """
            vnotation RichIBIS extends IBIS {
                node type: Stakeholder [nodeStyle: withCategory, color: "#884499", category: "S"]

                edge type: stakeholder_raises  from: Stakeholder to: Question
                edge type: stakeholder_answers from: Stakeholder to: Answer
            }

            vgraph analysis: RichIBIS "Stakeholder Analysis" {
                node q1: Question    "Should we rewrite?"
                node s1: Stakeholder "Engineering team"
                edge s1 -> q1
            }
            """

        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: input)

        // Both IBIS base types and the new Stakeholder type are registered
        let registeredTypeIds = graph.nodeTypes.map { $0.id }
        #expect(registeredTypeIds.contains("Question"))
        #expect(registeredTypeIds.contains("Stakeholder"))

        // Correct nodes and edges were created
        #expect(graph.nodes.count == 2)
        #expect(graph.edges.count == 1)
    }

    // MARK: - vnotation extends: override existing node/edge types

    @Test
    func testVNotationOverrideColorOnly() throws {
        // Override just the color — nodeStyle omitted, base's iconWithText is preserved.
        let input = """
            vnotation RedIBIS extends IBIS {
                node type: Question [color: "#ff0000"]
            }

            vgraph r1: RedIBIS "Red Questions" {
                node q1: Question "Why?"
                node a1: Answer   "Because"
                edge a1 -> q1
            }
            """

        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: input)

        // All base IBIS types are still present
        let typeIds = graph.nodeTypes.map { $0.id }
        #expect(typeIds.contains("Question"))
        #expect(typeIds.contains("Answer"))
        #expect(typeIds.contains("Pro"))
        #expect(typeIds.contains("Con"))

        // Question's color was overridden to red
        let questionType = NodeType(string: "Question")
        let questionColor: VColor = try graph.get(nodeType: questionType, attribute: Attributes.Node.backgroundColor)
        #expect(questionColor == VColor(hexString: "#ff0000"))

        // Question's nodeStyle is preserved from base IBIS
        let nodeStyle: NodeStyle = try graph.get(nodeType: questionType, attribute: Attributes.Node.nodeStyle)
        #expect(nodeStyle == .presetLayout)

        // Answer retains its original IBIS color (not overridden)
        let answerType = NodeType(string: "Answer")
        let answerColor: VColor = try graph.get(nodeType: answerType, attribute: Attributes.Node.backgroundColor)
        #expect(answerColor != VColor(hexString: "#ff0000"))

        #expect(graph.nodes.count == 2)
        #expect(graph.edges.count == 1)
    }

    @Test
    func testVNotationMissingNodeStyleIsError() throws {
        // nodeStyle is required for every node type declaration.
        let input = """
            vnotation BadMap {
                node type: Idea [color: "#336699"]
                edge type: link from: Idea to: Idea
            }

            vgraph b1: BadMap "Bad" {
                node i1: Idea "Think"
            }
            """

        let parser = VGraphParser(logger: NoOpLogger())
        #expect(throws: VError.self) {
            try parser.parse(source: input)
        }
    }

    @Test
    func testVNotationOverrideExplicitNodeStyle() throws {
        let input = """
            vnotation BareIBIS extends IBIS {
                node type: Question [nodeStyle: bareText, color: "#ff0000"]
            }

            vgraph b1: BareIBIS "Bare" {
                node q1: Question "Why?"
            }
            """

        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: input)

        let questionType = NodeType(string: "Question")
        let nodeStyle: NodeStyle = try graph.get(nodeType: questionType, attribute: Attributes.Node.nodeStyle)
        #expect(nodeStyle == .bareText)
    }

    @Test
    func testVNotationOverrideMixedNewAndExisting() throws {
        let input = """
            vnotation MixedIBIS extends IBIS {
                node type: Question    [color: "#ff0000"]
                node type: Stakeholder [nodeStyle: withCategory, color: "#884499", category: "S"]
            }

            vgraph m1: MixedIBIS "Mixed" {
                node q1: Question    "Why?"
                node s1: Stakeholder "Team"
                edge s1 -> q1
            }
            """

        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: input)

        // Override: Question still present, color changed
        let questionType = NodeType(string: "Question")
        let questionColor: VColor = try graph.get(nodeType: questionType, attribute: Attributes.Node.backgroundColor)
        #expect(questionColor == VColor(hexString: "#ff0000"))

        // New: Stakeholder was added
        let typeIds = graph.nodeTypes.map { $0.id }
        #expect(typeIds.contains("Stakeholder"))

        #expect(graph.nodes.count == 2)
        #expect(graph.edges.count == 1)
    }

    @Test
    func testVNotationOverrideEdgeTypeNoError() throws {
        // Redeclaring an existing edge type in extends mode should not throw.
        let input = """
            vnotation SameIBIS extends IBIS {
                edge type: answered_by from: Question to: Answer
            }

            vgraph e1: SameIBIS "Same edges" {
                node q1: Question "Why?"
                node a1: Answer   "Because"
                edge a1 -> q1
            }
            """

        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: input)

        #expect(graph.nodes.count == 2)
        #expect(graph.edges.count == 1)
    }

    @Test
    func testVNotationWithAnnotationExtension() throws {
        let input = """
            vnotation SimpleMap {
                node type: Concept [nodeStyle: simpleRoundedText, color: "#336699"]
                edge type: related  from: Concept to: Concept
            }

            vgraph sm1: SimpleMap, Annotation "Annotated Map" {
                node c1: Concept    "Main idea"
                node a1: Annotation "See also: section 3"
                edge c1 -> a1
            }
            """

        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: input)

        let registeredTypeIds = graph.nodeTypes.map { $0.id }
        #expect(registeredTypeIds.contains("Concept"))
        #expect(registeredTypeIds.contains("Annotation"))
        #expect(graph.nodes.count == 2)
    }

    @Test
    func testVNotationUnknownNodeStyleThrows() throws {
        let input = """
            vnotation BadStyle {
                node type: Foo [nodeStyle: doesNotExist, color: "#ff0000"]
            }

            vgraph bg1: BadStyle "Bad" {
                node f1: Foo "test"
            }
            """

        let parser = VGraphParser(logger: NoOpLogger())
        #expect(throws: (any Error).self) {
            _ = try parser.parse(source: input)
        }
    }
}

// MARK: - Attribute Round-Trip Tests

@Suite("Attribute Round-Trip Tests")
struct AttributeRoundTripTests {

    private let parser = VGraphParser(logger: NoOpLogger())
    private let exporter = VGLExporter()

    /// Parse → export → re-parse, returning the re-parsed graph.
    private func roundTrip(_ input: String) throws -> (VGraph, VGraph) {
        let g1 = try parser.parse(source: input)
        let exported = try exporter.export(graph: g1)
        let g2 = try parser.parse(source: exported)
        return (g1, g2)
    }

    // MARK: - Test value generation

    /// Returns a non-default VGL-ready test value string for a given attribute type,
    /// or nil if the type cannot be round-tripped through VGL.
    /// Bare where VGL reads a single token; quoted otherwise.
    private static func literal(_ value: String) -> String {
        let bare = value.allSatisfy { $0.isLetter || $0.isNumber || $0 == "." || $0 == "_" }
        return bare ? value : "\"\(StringEscaping.escape(value))\""
    }

    /// Every authorable attribute must have a value to test with.
    private static func untested(_ defs: [AttributeDefinition]) -> [String] {
        defs.filter { testValue(for: $0) == nil }.map { "\($0.id.description) (\($0.typeAsString))" }.sorted()
    }

    private static func testValue(for def: AttributeDefinition) -> String? {
        switch def.typeAsString {
        case "String":
            if def.defaultValue.isEmpty { return "test_value" }
            return "custom_string"
        case "Double":
            return "42.00"
        case "Bool":
            return def.defaultValue == "true" ? "false" : "true"
        case "Int":
            return "99"
        case "Color":
            // `VColor.typeName` is "Color" too, and a hex parses as either.
            return "#ff00ff"
        case "VColor":
            return "#ff00ffff"
        case "FontFamily":
            return "Georgia"
        case "LayoutDirection":
            return "leftToRight"
        case "DiagramLogic":
            return "sufficientCause"
        case "Ratio":
            return "compress"
        case LoopMarkers.typeName:
            return LoopMarkers.none.asString
        case NodeShape.typeName:
            return NodeShape.circle.asString
        case NodeStyle.typeName:
            return NodeStyle.withCategory.asString
        case NodeStyleLayout.typeName:
            return NodeStyleLayout.bareText.asString
        case GroupStyle.typeName:
            return GroupStyle(folded: .bareText, unfolded: .default).asString
        case BoundaryChrome.typeName:
            return BoundaryChrome(cornerRadius: 2, borderDash: "2,2").asString
        case IconInfo.typeName:
            return IconInfo(iconPosition: .none, iconName: "and", iconColor: VColor.green, iconSize: 24).asString
        default:
            if def.typeAsString.contains("StyleType") {
                return "dashed"
            }
            if def.typeAsString.contains("Labeljust") {
                return "l"
            }
            return nil
        }
    }

    // MARK: - Excluded attribute IDs

    /// Attributes handled structurally or internal-only.
    private static let excludedAttributeIds: Set<Attribute.Id> = [
        Attributes.Group.Id.id,
        Attributes.Group.label.id,
        Attributes.Group.isFolded.id,
        Attributes.Node.label.id,
        Attributes.Edge.label.id,
    ]

    // MARK: - Loop: Graph-level attributes

    /// Verifies that every persistent, graph-level attribute survives VGL round-trip.
    @Test
    func allGraphAttributesRoundTrip() throws {
        let seed = try parser.parse(
            source: """
                vgraph t: IBIS "T" {
                    node n1: Question "Q"
                }
                """)

        let graphDefs = seed.attributeDefinitions.values.filter { def in
            def.target == .graph && def.category != .computed
                && !Self.excludedAttributeIds.contains(def.id)
        }

        #expect(Self.untested(Array(graphDefs)).isEmpty, "No test value for \(Self.untested(Array(graphDefs)))")
        var tested = 0
        for def in graphDefs {
            guard let testVal = Self.testValue(for: def) else { continue }
            let vglKey = def.vglKey
            let quotedVal = Self.literal(testVal)

            let vgl = """
                vgraph t: IBIS "T" {
                    \(vglKey): \(quotedVal)
                    node n1: Question "Q"
                }
                """
            let (g1, g2) = try roundTrip(vgl)
            let v1 = try g1.attributes(in: .model, of: .root)[def.id]
            let v2 = try g2.attributes(in: .model, of: .root)[def.id]
            #expect(v1 != nil, "Attribute \(def.name) (\(vglKey)) should be set after parse")
            #expect(v1 == v2, "Attribute \(def.name) (\(vglKey)) should survive round-trip: '\(v1 ?? "nil")' vs '\(v2 ?? "nil")'")
            #expect(v1 != def.defaultValue, "Attribute \(def.name) (\(vglKey)) test value should differ from default")
            tested += 1
        }

        #expect(tested >= 10, "Expected at least 10 graph-level attributes to be tested, got \(tested)")
    }

    // MARK: - Loop: Group-level attributes

    /// Verifies that every persistent, group-level attribute survives VGL round-trip
    /// when set on a non-root group.
    @Test
    func allGroupAttributesRoundTrip() throws {
        let seed = try parser.parse(
            source: """
                vgraph t: IBIS "T" {
                    group g1 "G" {
                        node n1: Question "Q"
                    }
                }
                """)

        let graphOnlyIds: Set<Attribute.Id> = [
            Attributes.Group.layoutDirection.id,
            Attributes.Group.diagramLogic.id,
            Attributes.Group.layoutEngine.id,
            Attributes.Group.maxNodeWidth.id,
            Attributes.Group.watermark.id,
        ]

        let groupDefs = seed.attributeDefinitions.values.filter { def in
            def.target == .graph && def.category != .computed
                && !Self.excludedAttributeIds.contains(def.id)
                && !graphOnlyIds.contains(def.id) && !def.isDiagramOnly
        }

        #expect(Self.untested(Array(groupDefs)).isEmpty, "No test value for \(Self.untested(Array(groupDefs)))")
        var tested = 0
        for def in groupDefs {
            guard let testVal = Self.testValue(for: def) else { continue }
            let vglKey = def.vglKey
            let quotedVal = Self.literal(testVal)

            let vgl = """
                vgraph t: IBIS "T" {
                    group g1 "G" {
                        \(vglKey): \(quotedVal)
                        node n1: Question "Q"
                    }
                }
                """
            let (g1, g2) = try roundTrip(vgl)
            let grp1 = g1.groups.first { $0.id.description == "g1" }!
            let grp2 = g2.groups.first { $0.id.description == "g1" }!
            let v1 = try g1.getAttributes(group: grp1)[def.id]
            let v2 = try g2.getAttributes(group: grp2)[def.id]
            #expect(v1 != nil, "Group attribute \(def.name) (\(vglKey)) should be set after parse")
            #expect(v1 == v2, "Group attribute \(def.name) (\(vglKey)) should survive round-trip: '\(v1 ?? "nil")' vs '\(v2 ?? "nil")'")
            tested += 1
        }

        #expect(tested >= 5, "Expected at least 5 group-level attributes to be tested, got \(tested)")
    }

    // MARK: - Loop: Node-level attributes

    /// Verifies that every persistent, node-level attribute survives VGL round-trip.
    @Test
    func allNodeAttributesRoundTrip() throws {
        let seed = try parser.parse(
            source: """
                vgraph t: IBIS "T" {
                    node n1: Question "Q"
                }
                """)

        let nodeDefs = seed.attributeDefinitions.values.filter { def in
            def.target == .node && def.category != .computed
                && !Self.excludedAttributeIds.contains(def.id)
        }

        #expect(Self.untested(Array(nodeDefs)).isEmpty, "No test value for \(Self.untested(Array(nodeDefs)))")
        var tested = 0
        for def in nodeDefs {
            guard let testVal = Self.testValue(for: def) else { continue }
            let vglKey = def.vglKey
            let quotedVal = Self.literal(testVal)

            let vgl = """
                vgraph t: IBIS "T" {
                    node n1: Question "Q" [\(vglKey): \(quotedVal)]
                }
                """
            let (g1, g2) = try roundTrip(vgl)
            let n1 = g1.nodes.first { $0.id.description == "n1" }!
            let n2 = g2.nodes.first { $0.id.description == "n1" }!
            let v1 = g1.getOwnAttributes(node: n1)[def.id]
            let v2 = g2.getOwnAttributes(node: n2)[def.id]
            #expect(v1 != nil, "Node attribute \(def.name) (\(vglKey)) should be set after parse")
            #expect(v1 == v2, "Node attribute \(def.name) (\(vglKey)) should survive round-trip: '\(v1 ?? "nil")' vs '\(v2 ?? "nil")'")
            tested += 1
        }

        #expect(tested >= 3, "Expected at least 3 node-level attributes to be tested, got \(tested)")
    }

    // MARK: - Loop: Edge-level attributes

    /// Verifies that every persistent, edge-level attribute survives VGL round-trip.
    @Test
    func allEdgeAttributesRoundTrip() throws {
        let seed = try parser.parse(
            source: """
                vgraph t: IBIS "T" {
                    node n1: Question "Q"
                    node n2: Answer "A"
                    edge n2 -> n1
                }
                """)

        let edgeDefs = seed.attributeDefinitions.values.filter { def in
            def.target == .edge && def.category != .computed
                && !Self.excludedAttributeIds.contains(def.id)
        }

        #expect(Self.untested(Array(edgeDefs)).isEmpty, "No test value for \(Self.untested(Array(edgeDefs)))")
        var tested = 0
        for def in edgeDefs {
            guard let testVal = Self.testValue(for: def) else { continue }
            let vglKey = def.vglKey
            let quotedVal = Self.literal(testVal)

            let vgl = """
                vgraph t: IBIS "T" {
                    node n1: Question "Q"
                    node n2: Answer "A"
                    edge n2 -> n1 [\(vglKey): \(quotedVal)]
                }
                """
            let (g1, g2) = try roundTrip(vgl)
            let e1 = g1.edges.first!.id
            let e2 = g2.edges.first!.id
            let v1 = g1.getOwnAttributes(edge: e1)[def.id]
            let v2 = g2.getOwnAttributes(edge: e2)[def.id]
            #expect(v1 != nil, "Edge attribute \(def.name) (\(vglKey)) should be set after parse")
            #expect(v1 == v2, "Edge attribute \(def.name) (\(vglKey)) should survive round-trip: '\(v1 ?? "nil")' vs '\(v2 ?? "nil")'")
            tested += 1
        }

        #expect(tested >= 8, "Expected at least 8 edge-level attributes to be tested, got \(tested)")
    }

    // MARK: - Specific edge cases

    @Test
    func graphLayoutDirectionUsesRankdirAlias() throws {
        let (g1, g2) = try roundTrip(
            """
            vgraph t: IBIS "T" {
                rankdir: LR
                node n1: Question "Q"
            }
            """)
        let v1: String = try g1.get(graphAttribute: Attributes.Group.layoutDirection)
        let v2: String = try g2.get(graphAttribute: Attributes.Group.layoutDirection)
        // "rankdir" resolves to layoutDirection via alias; value stored as-is (type-erased path)
        #expect(v1 == v2, "Layout direction should survive round-trip")
    }

    @Test
    func edgeLabelRoundTrip() throws {
        let (g1, g2) = try roundTrip(
            """
            vgraph t: IBIS "T" {
                node n1: Question "Q"
                node n2: Answer "A"
                edge n2 -> n1 "supports"
            }
            """)
        let v1: String = try g1.get(edge: g1.edges.first!.id, attribute: Attributes.Edge.label)
        let v2: String = try g2.get(edge: g2.edges.first!.id, attribute: Attributes.Edge.label)
        #expect(v1 == "supports")
        #expect(v2 == v1)
    }

    @Test
    func groupIsFoldedRoundTrip() throws {
        let (g1, g2) = try roundTrip(
            """
            vgraph t: IBIS "T" {
                folded group g1 "G" {
                    node n1: Question "Q"
                }
            }
            """)
        let grp1 = g1.groups.first { $0.id.description == "g1" }!
        let grp2 = g2.groups.first { $0.id.description == "g1" }!
        let v1: Bool = try g1.get(group: grp1, attribute: Attributes.Group.isFolded)
        let v2: Bool = try g2.get(group: grp2, attribute: Attributes.Group.isFolded)
        #expect(v1 == true)
        #expect(v2 == v1)
    }
}

// MARK: - Timeline Notation Tests

struct TimelineNotationTests {

    let timelineInput = """
        vgraph myTimeline: Timeline "19th Century Europe" {
            node t1800: TimePoint "1800" [alignGroup: "1800"]
            node t1850: TimePoint "1850" [alignGroup: "1850"]
            node t1871: TimePoint "1871" [alignGroup: "1871"]
            edge t1800 -> t1850: sequence
            edge t1850 -> t1871: sequence

            group germany "Germany" {
                node g1: Event "Napoleon defeats Prussia" [alignGroup: "1800"]
                node g2: Event "German Unification" [alignGroup: "1871"]
            }
            group england "England" {
                node e1: Event "Industrial Revolution peaks" [alignGroup: "1850"]
                node e2: Event "Franco-Prussian War impact" [alignGroup: "1871"]
            }

            edge g1 -> g2: influence "led to"
            edge e1 -> e2: influence
            edge e1 -> g2: influence "industrialization enabled"
        }
        """

    @Test
    func fullCycleParseAndExportTimeline() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: timelineInput)

        #expect(graph.nodes.count == 7, "Should have 3 TimePoints + 2 Germany + 2 England events")
        #expect(graph.edges.count == 5, "Should have 2 sequence + 3 influence edges")

        let exporter = VGLExporter()
        let exported = try exporter.export(graph: graph)
        let graph2 = try parser.parse(source: exported)

        #expect(graph2.nodes.count == graph.nodes.count, "Node count should survive round-trip")
        #expect(graph2.edges.count == graph.edges.count, "Edge count should survive round-trip")
    }

    @Test
    func verifyTimelineNodeTypes() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: timelineInput)

        let nodeTypes = Set(try graph.nodes.map { try graph.nodeType(for: $0).id })
        #expect(nodeTypes.contains("TimePoint"), "Should have TimePoint node type")
        #expect(nodeTypes.contains("Event"), "Should have Event node type")
    }

    @Test
    func exportTimelineToDotWithAlignGroups() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: timelineInput)

        let exporter = DotExporter()
        let dotOutput = try exporter.export(graph: graph)

        // Verify newrank=true is emitted (required for rank=same with clusters)
        #expect(dotOutput.contains("newrank=true"), "DOT output should contain newrank=true when alignGroups are used")

        #expect(dotOutput.contains("rank=same"), "DOT output should contain rank=same blocks")

        #expect(dotOutput.contains("LR") || dotOutput.contains("leftToRight"), "Should use left-to-right layout")
    }

    @Test
    func alignGroupRoundTrip() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: timelineInput)

        let t1800 = graph.nodes.first { $0.id.description == "t1800" }!
        let alignGroup: String = try graph.get(node: t1800, attribute: Attributes.Node.alignGroup)
        #expect(alignGroup == "1800", "alignGroup should be set to '1800'")

        let exporter = VGLExporter()
        let exported = try exporter.export(graph: graph)
        let graph2 = try parser.parse(source: exported)

        let t1800_2 = graph2.nodes.first { $0.id.description == "t1800" }!
        let alignGroup2: String = try graph2.get(node: t1800_2, attribute: Attributes.Node.alignGroup)
        #expect(alignGroup2 == "1800", "alignGroup should survive VGL round-trip")
    }

    @Test
    func timelineWithoutTimePoints() throws {
        let input = """
            vgraph simple: Timeline "Simple Timeline" {
                node e1: Event "Event A" [alignGroup: "phase1"]
                node e2: Event "Event B" [alignGroup: "phase1"]
                node e3: Event "Event C" [alignGroup: "phase2"]
                edge e1 -> e3: influence
            }
            """

        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: input)

        #expect(graph.nodes.count == 3, "Should have 3 events without TimePoints")

        let exporter = DotExporter()
        let dotOutput = try exporter.export(graph: graph)
        #expect(dotOutput.contains("rank=same"), "Should still emit rank=same for alignGroup")
    }

    @Test
    func timelineGColorsMatchStaticConstants() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: timelineInput)

        let exporter = DotExporter()
        let dotOutput = try exporter.export(graph: graph)

        let eventFill = try #require(
            graph.effectiveNodeLayout(for: Notations.Timeline.NodeTypes.event)?.backgroundFill)
        #expect(dotOutput.contains(eventFill.hexString))
        // TimePoint nodes no longer set a Graphviz color — they are drawn by
        // `TimelineOverlayProvider` (axis + dots + year labels) instead of
        // the standard node pipeline, so no `gray` hint is set in DOT.
    }

    // MARK: - vnotation export reconstruction tests

    @Test
    func testVNotationExportPure() throws {
        let input = """
            vnotation RiskMap {
                layout: leftToRight

                node type: Risk    [nodeStyle: iconWithText, color: "#cc3333", icon: "risk"]
                node type: Control [nodeStyle: simpleRoundedText, color: "#339933"]
                node type: Owner   [nodeStyle: circle, color: "#3366cc"]

                edge type: risk_has_control  from: Risk    to: Control
                edge type: control_owned_by  from: Control to: Owner
            }

            vgraph rm1: RiskMap "Risk Analysis" {
                node r1: Risk    "Data breach"
                node c1: Control "Encryption"
                node o1: Owner   "Security team"
                edge r1 -> c1
                edge c1 -> o1
            }
            """

        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: input)

        let exporter = VGLExporter()
        let exported = try exporter.export(graph: graph)

        #expect(exported.contains("vnotation RiskMap {"), "Exported VGL should contain vnotation declaration")
        #expect(exported.contains("node type: Risk"), "Exported VGL should contain Risk node type")
        #expect(exported.contains("node type: Control"), "Exported VGL should contain Control node type")
        #expect(exported.contains("node type: Owner"), "Exported VGL should contain Owner node type")
        #expect(exported.contains("edge type: risk_has_control"), "Exported VGL should contain edge type")
        #expect(exported.contains("edge type: control_owned_by"), "Exported VGL should contain edge type")
        #expect(exported.contains("layout: leftToRight"), "Exported VGL should contain layout directive")

        let parser2 = VGraphParser(logger: NoOpLogger())
        let graph2 = try parser2.parse(source: exported)
        #expect(graph2.nodes.count == 3)
        #expect(graph2.edges.count == 2)
        #expect(graph2.nodeTypes.count == graph.nodeTypes.count)
    }

    @Test
    func testVNotationExportExtends() throws {
        let input = """
            vnotation RichIBIS extends IBIS {
                node type: Stakeholder [nodeStyle: withCategory, color: "#884499", category: "S"]

                edge type: stakeholder_raises  from: Stakeholder to: Question
                edge type: stakeholder_answers from: Stakeholder to: Answer
            }

            vgraph analysis: RichIBIS "Stakeholder Analysis" {
                node q1: Question    "Should we rewrite?"
                node s1: Stakeholder "Engineering team"
                edge s1 -> q1
            }
            """

        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: input)

        let exporter = VGLExporter()
        let exported = try exporter.export(graph: graph)

        #expect(exported.contains("vnotation RichIBIS extends IBIS"), "Exported VGL should contain extends clause")
        #expect(exported.contains("node type: Stakeholder"), "Exported VGL should contain new Stakeholder type")
        #expect(exported.contains("edge type: stakeholder_raises"), "Exported VGL should contain new edge type")

        // Base IBIS types should NOT appear in the vnotation block (they're inherited)
        // Split the output to get just the vnotation block
        let vnotationBlock = exported.components(separatedBy: "vgraph").first ?? ""
        #expect(!vnotationBlock.contains("node type: Question"), "Base IBIS types should not be in vnotation block")
        #expect(!vnotationBlock.contains("node type: Answer"), "Base IBIS types should not be in vnotation block")

        let parser2 = VGraphParser(logger: NoOpLogger())
        let graph2 = try parser2.parse(source: exported)
        #expect(graph2.nodes.count == 2)
        #expect(graph2.edges.count == 1)

        let registeredTypeIds = graph2.nodeTypes.map { $0.id }
        #expect(registeredTypeIds.contains("Question"))
        #expect(registeredTypeIds.contains("Stakeholder"))
    }

    @Test
    func testVNotationExportOverride() throws {
        let input = """
            vnotation RedIBIS extends IBIS {
                node type: Question [color: "#ff0000"]
            }

            vgraph r1: RedIBIS "Red Questions" {
                node q1: Question "Why?"
                node a1: Answer   "Because"
                edge a1 -> q1
            }
            """

        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: input)

        let exporter = VGLExporter()
        let exported = try exporter.export(graph: graph)

        #expect(exported.contains("vnotation RedIBIS extends IBIS"), "Should contain extends clause")
        #expect(exported.contains("node type: Question"), "Override type should appear")
        #expect(exported.contains("#ff0000"), "Override color should appear")

        // Roundtrip
        let parser2 = VGraphParser(logger: NoOpLogger())
        let graph2 = try parser2.parse(source: exported)
        #expect(graph2.nodes.count == 2)
        #expect(graph2.edges.count == 1)
    }

    // MARK: - Edge type attribute tests

    @Test
    func testVNotationEdgeTypeAttributes() throws {
        let input = """
            vnotation StyledMap {
                layout: topToBottom

                node type: Source [nodeStyle: simpleRoundedText, color: "#336699"]
                node type: Target [nodeStyle: simpleRoundedText, color: "#996633"]

                edge type: link  from: Source  to: Target [arrowHead: vee, style: dashed, color: "#cc0000", penwidth: 2.5, constraint: true, dir: both]
            }

            vgraph sm1: StyledMap "Styled" {
                node s1: Source "A"
                node t1: Target "B"
                edge s1 -> t1
            }
            """

        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: input)

        let linkId = EdgeType.Id(rawValue: "link")
        let arrowHead: String = try graph.get(edgeType: linkId, attribute: Attributes.Edge.arrowHead)
        #expect(arrowHead == "vee")

        let style: Attributes.Edge.StyleType = try graph.get(edgeType: linkId, attribute: Attributes.Edge.style)
        #expect(style == .dashed)

        let gColor: VColor = try graph.get(edgeType: linkId, attribute: Attributes.Edge.color)
        #expect(gColor.asString.contains("cc0000"))

        let penwidth: Double = try graph.get(edgeType: linkId, attribute: Attributes.Edge.penwidth)
        #expect(penwidth == 2.5)

        let constraint: Bool = try graph.get(edgeType: linkId, attribute: Attributes.Edge.constraint)
        #expect(constraint == true)

        let dir: String = try graph.get(edgeType: linkId, attribute: Attributes.Edge.dir)
        #expect(dir == "both")
    }

    @Test
    func testVNotationEdgeTypeAttributeRoundTrip() throws {
        let input = """
            vnotation StyledMap {
                layout: topToBottom

                node type: Source [nodeStyle: simpleRoundedText, color: "#336699"]
                node type: Target [nodeStyle: simpleRoundedText, color: "#996633"]

                edge type: link  from: Source  to: Target [arrowHead: vee, style: dashed, color: "#cc0000", penwidth: 2.5, dir: both]
            }

            vgraph sm1: StyledMap "Styled" {
                node s1: Source "A"
                node t1: Target "B"
                edge s1 -> t1
            }
            """

        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: input)

        let exporter = VGLExporter()
        let exported = try exporter.export(graph: graph)

        #expect(exported.contains("arrowHead: vee"), "Exported should contain arrowHead")
        #expect(exported.contains("style: dashed"), "Exported should contain style")
        #expect(exported.contains("cc0000"), "Exported should contain color hex")
        #expect(exported.contains("penwidth: 2.5"), "Exported should contain penwidth")
        #expect(exported.contains("dir: both"), "Exported should contain dir")

        // Re-parse and verify attributes survive round-trip
        let parser2 = VGraphParser(logger: NoOpLogger())
        let graph2 = try parser2.parse(source: exported)

        let linkId = EdgeType.Id(rawValue: "link")
        let arrowHead: String = try graph2.get(edgeType: linkId, attribute: Attributes.Edge.arrowHead)
        #expect(arrowHead == "vee")

        let style: Attributes.Edge.StyleType = try graph2.get(edgeType: linkId, attribute: Attributes.Edge.style)
        #expect(style == .dashed)

        let penwidth: Double = try graph2.get(edgeType: linkId, attribute: Attributes.Edge.penwidth)
        #expect(penwidth == 2.5)

        let dir: String = try graph2.get(edgeType: linkId, attribute: Attributes.Edge.dir)
        #expect(dir == "both")
    }

    @Test
    func testVNotationEdgeTypeOverrideAttributes() throws {
        let input = """
            vnotation FastTimeline extends Timeline {
                edge type: sequence  from: TimePoint  to: TimePoint [style: bold, penwidth: 3.0, color: "#ff0000"]
            }

            vgraph ft1: FastTimeline "Fast" {
                node tp1: TimePoint "2024"
                node tp2: TimePoint "2025"
                edge tp1 -> tp2
            }
            """

        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: input)

        // Overridden attributes on sequence
        let seqId = EdgeType.Id(rawValue: "sequence")
        let style: Attributes.Edge.StyleType = try graph.get(edgeType: seqId, attribute: Attributes.Edge.style)
        #expect(style == .bold)

        let penwidth: Double = try graph.get(edgeType: seqId, attribute: Attributes.Edge.penwidth)
        #expect(penwidth == 3.0)

        let gColor: VColor = try graph.get(edgeType: seqId, attribute: Attributes.Edge.color)
        #expect(gColor.asString.contains("ff0000"))

        // influence edge type should still exist from base
        let infId = EdgeType.Id(rawValue: "influence")
        let infStyle: Attributes.Edge.StyleType = try graph.get(edgeType: infId, attribute: Attributes.Edge.style)
        #expect(infStyle == .dashed, "Base influence style should be preserved")
    }

    @Test
    func testVNotationEdgeTypeExportOverride() throws {
        let input = """
            vnotation FastTimeline extends Timeline {
                edge type: sequence  from: TimePoint  to: TimePoint [style: bold, penwidth: 3.0, color: "#ff0000"]
            }

            vgraph ft1: FastTimeline "Fast" {
                node tp1: TimePoint "2024"
                node tp2: TimePoint "2025"
                edge tp1 -> tp2
            }
            """

        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: input)

        let exporter = VGLExporter()
        let exported = try exporter.export(graph: graph)

        // Overridden edge type should appear with only changed attributes
        #expect(exported.contains("edge type: sequence"), "Overridden edge should be exported")
        #expect(exported.contains("style: bold"), "Changed style should appear")
        #expect(exported.contains("penwidth: 3"), "Changed penwidth should appear")
        #expect(exported.contains("ff0000"), "Changed color should appear")

        // influence should NOT appear (unchanged from base)
        #expect(!exported.contains("edge type: influence"), "Unchanged base edge should not be exported")

        // Roundtrip
        let parser2 = VGraphParser(logger: NoOpLogger())
        let graph2 = try parser2.parse(source: exported)
        #expect(graph2.nodes.count == 2)
        #expect(graph2.edges.count == 1)
    }

    @Test
    func testVNotationExportBuiltinNotExported() throws {
        // A graph using a built-in notation should NOT have a vnotation block
        let input = """
            vgraph test1: IBIS "Simple IBIS" {
                node q1: Question "Why?"
                node a1: Answer   "Because"
                edge a1 -> q1
            }
            """

        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: input)

        let exporter = VGLExporter()
        let exported = try exporter.export(graph: graph)

        #expect(!exported.contains("vnotation"), "Built-in notation should not produce a vnotation block")
    }

    // MARK: - diagramLogic in vnotation

    @Test
    func testVNotationDiagramLogicStandalone() throws {
        let input = """
            vnotation LogicMap {
                layout: topToBottom
                diagramLogic: sufficientCause

                node type: Cause   [nodeStyle: simpleRoundedText, color: "#cc3333"]
                node type: Effect  [nodeStyle: simpleRoundedText, color: "#339933"]

                edge type: causes from: Cause to: Effect
            }

            vgraph lm1: LogicMap "Logic Test" {
                node c1: Cause  "Fire"
                node e1: Effect "Smoke"
                edge c1 -> e1
            }
            """

        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: input)

        // diagramLogic was applied
        let logic: String = try graph.get(graphAttribute: Attributes.Group.diagramLogic)
        let parsed = try DiagramLogic.fromString(logic)
        #expect(parsed == .sufficientCause)

        // Round-trip: export and re-parse
        let exporter = VGLExporter()
        let exported = try exporter.export(graph: graph)
        #expect(exported.contains("diagramLogic") || exported.contains("diagramlogic"))
        #expect(exported.contains("sufficientCause"))

        let graph2 = try parser.parse(source: exported)
        let logic2: String = try graph2.get(graphAttribute: Attributes.Group.diagramLogic)
        let parsed2 = try DiagramLogic.fromString(logic2)
        #expect(parsed2 == .sufficientCause)
    }

    @Test
    func testVNotationDiagramLogicExtendsOverride() throws {
        // CRT uses sufficientCause by default; override to necessaryCondition
        let input = """
            vnotation CustomCRT extends CRT {
                diagramLogic: necessaryCondition
            }

            vgraph c1: CustomCRT "Custom CRT" {
                node u1: UndesirableEffect "Problem"
            }
            """

        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: input)

        let logic: String = try graph.get(graphAttribute: Attributes.Group.diagramLogic)
        let parsed = try DiagramLogic.fromString(logic)
        #expect(parsed == .necessaryCondition)

        let exporter = VGLExporter()
        let exported = try exporter.export(graph: graph)
        #expect(exported.contains("necessaryCondition"))
    }

    @Test
    func testVNotationDiagramLogicExtendsPreserved() throws {
        // CRT uses sufficientCause; vnotation doesn't override it
        let input = """
            vnotation StyledCRT extends CRT {
                node type: UndesirableEffect [color: "#ff0000"]
            }

            vgraph s1: StyledCRT "Styled CRT" {
                node u1: UndesirableEffect "Problem"
            }
            """

        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: input)

        // Base CRT's diagramLogic should be preserved
        let logic: String = try graph.get(graphAttribute: Attributes.Group.diagramLogic)
        let parsed = try DiagramLogic.fromString(logic)
        #expect(parsed == .sufficientCause)
    }

    @Test
    func testVNotationDiagramLogicDefaultNoLogic() throws {
        // Standalone vnotation without diagramLogic should default to noLogic
        let input = """
            vnotation Simple {
                layout: topToBottom
                node type: Thing [nodeStyle: simpleRoundedText, color: "#666666"]
                edge type: link from: Thing to: Thing
            }

            vgraph s1: Simple "Simple" {
                node t1: Thing "A"
                node t2: Thing "B"
                edge t1 -> t2
            }
            """

        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: input)

        let logic: String = try graph.get(graphAttribute: Attributes.Group.diagramLogic)
        let parsed = try DiagramLogic.fromString(logic)
        #expect(parsed == .noLogic)
    }

    @Test
    func testVNotationUnknownGraphAttrThrows() throws {
        let input = """
            vnotation Bad {
                layout: topToBottom
                unknownAttr: someValue
                node type: Thing [nodeStyle: simpleRoundedText, color: "#666666"]
                edge type: link from: Thing to: Thing
            }

            vgraph b1: Bad "Bad" {
            }
            """

        let parser = VGraphParser(logger: NoOpLogger())
        #expect(throws: VError.self) {
            _ = try parser.parse(source: input)
        }
    }

    // MARK: - Quality Check and Transform Registry Tests

    @Test
    func testVNotationQualityCheckTreeStructure() throws {
        let input = """
            vnotation TreeNotation {
                node type: Parent [nodeStyle: roundedBox, color: "#336699"]
                node type: Child  [nodeStyle: simpleRoundedText, color: "#669933"]
                edge type: parent_child from: Parent to: Child
                qualityCheck: treeStructure
            }

            vgraph t1: TreeNotation "Tree Test" {
                node p1: Parent "Root"
                node p2: Parent "Other Root"
                node c1: Child  "Leaf"
                edge p1 -> c1
                edge p2 -> c1
            }
            """

        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: input)

        let storedChecks = graph.notationDefinition.declaredQualityChecks.map { $0.specString }
        #expect(storedChecks == ["treeStructure"])

        // Run quality analysis — the tree structure check should fire
        let report = Notations.analyzeQuality(graph: graph)
        let treeWarnings = report.warnings.filter { $0.message.contains("parent nodes") }
        #expect(treeWarnings.count == 1)
        #expect(treeWarnings[0].message.contains("Leaf"))
    }

    @Test
    func testVNotationQualityCheckNodeCountRange() throws {
        let input = """
            vnotation CountTest {
                node type: Item [nodeStyle: simpleRoundedText, color: "#336699"]
                edge type: link from: Item to: Item
                qualityCheck: nodeCountRange(Item, 2, 5)
            }

            vgraph c1: CountTest "Count Test" {
                node i1: Item "One"
            }
            """

        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: input)
        let report = Notations.analyzeQuality(graph: graph)
        let countWarnings = report.warnings.filter { $0.message.contains("Item count") }
        #expect(countWarnings.count == 1)
        #expect(countWarnings[0].message.contains("1"))
    }

    @Test
    func testVNotationQualityCheckExactlyOne() throws {
        let input = """
            vnotation RootTest {
                node type: Root [nodeStyle: roundedBox, color: "#cc3333"]
                node type: Leaf [nodeStyle: simpleRoundedText, color: "#339933"]
                edge type: root_leaf from: Root to: Leaf
                qualityCheck: exactlyOne(Root)
            }

            vgraph r1: RootTest "Root Test" {
                node r1: Root "Root A"
                node r2: Root "Root B"
                node l1: Leaf "Leaf"
                edge r1 -> l1
                edge r2 -> l1
            }
            """

        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: input)
        let report = Notations.analyzeQuality(graph: graph)
        let rootErrors = report.errors.filter { $0.message.contains("Root") && $0.message.contains("exactly 1") }
        #expect(rootErrors.count == 1)
    }

    @Test
    func testVNotationQualityCheckLabelLength() throws {
        let input = """
            vnotation LabelTest {
                node type: Concept [nodeStyle: simpleRoundedText, color: "#336699"]
                edge type: link from: Concept to: Concept
                qualityCheck: labelLength(3)
            }

            vgraph l1: LabelTest "Label Test" {
                node c1: Concept "Short"
                node c2: Concept "This label has too many words"
                edge c1 -> c2
            }
            """

        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: input)
        let report = Notations.analyzeQuality(graph: graph)
        let labelWarnings = report.warnings.filter { $0.message.contains("words") }
        #expect(labelWarnings.count == 1)
        #expect(labelWarnings[0].message.contains("too many words"))
    }

    @Test
    func testVNotationMultipleQualityChecks() throws {
        let input = """
            vnotation MultiCheck {
                node type: Thing [nodeStyle: roundedBox, color: "#336699"]
                edge type: link from: Thing to: Thing
                qualityCheck: treeStructure
                qualityCheck: labelLength(2)
            }

            vgraph m1: MultiCheck "Multi Check" {
                node t1: Thing "One Two Three"
                node t2: Thing "Fine"
                node t3: Thing "Also Fine"
                edge t1 -> t3
                edge t2 -> t3
            }
            """

        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: input)

        let storedChecks = graph.notationDefinition.declaredQualityChecks.map { $0.specString }
        #expect(storedChecks.contains("treeStructure"))
        #expect(storedChecks.contains("labelLength(2)"))

        let report = Notations.analyzeQuality(graph: graph)
        // Tree structure warning (t3 has 2 parents)
        let treeWarnings = report.warnings.filter { $0.message.contains("parent nodes") }
        #expect(treeWarnings.count == 1)
        // Label length warning
        let labelWarnings = report.warnings.filter { $0.message.contains("words") }
        #expect(labelWarnings.count == 1)
    }

    @Test
    func testVNotationTransform() throws {
        let input = """
            vnotation WithTransform {
                node type: Item [nodeStyle: simpleRoundedText, color: "#336699"]
                edge type: link from: Item to: Item
                transform: identity
            }

            vgraph w1: WithTransform "Transform Test" {
                node i1: Item "One"
                node i2: Item "Two"
                edge i1 -> i2
            }
            """

        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: input)

        #expect(graph.notationDefinition.declaredTransforms == ["identity"])

        // Apply transform pipeline — identity should leave graph unchanged
        let transform = try Notations.resolveTransform(for: graph)
        let result = try transform(graph)
        #expect(result.nodes.count == graph.nodes.count)
        #expect(result.edges.count == graph.edges.count)
    }

    @Test
    func testVNotationExtendsReplacesQualityChecks() throws {
        // GoalTree has exactlyOneGoal + csfCount checks.
        // When we specify explicit qualityCheck: lines, those replace the base checks.
        let input = """
            vnotation CustomGoalTree extends GoalTree {
                qualityCheck: disconnectedNodes
            }

            vgraph g1: CustomGoalTree "Custom Goal Tree" {
                node g1: Goal "Main Goal"
                node c1: CriticalSuccessFactor "CSF 1"
                node nc1: NecessaryCondition "NC 1"
                edge g1 -> c1
                edge c1 -> nc1
            }
            """

        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: input)

        let report = Notations.analyzeQuality(graph: graph)
        // The base GoalTree csfCount check should NOT run (replaced by explicit checks).
        // GoalTree's csfCount would flag "1 CSF, recommended 3-5" as info.
        let csfMessages = report.infos.filter { $0.message.contains("Critical Success Factor") }
        #expect(csfMessages.isEmpty)
    }

    @Test
    func testVNotationQualityCheckRoundTrip() throws {
        let input = """
            vnotation RoundTripCheck {
                node type: Item [nodeStyle: simpleRoundedText, color: "#336699"]
                edge type: link from: Item to: Item
                qualityCheck: treeStructure
                qualityCheck: nodeCountRange(Item, 1, 10)
                transform: identity
            }

            vgraph rt1: RoundTripCheck "Round Trip" {
                node i1: Item "One"
            }
            """

        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: input)

        let exporter = VGLExporter()
        let exported = try exporter.export(graph: graph)

        #expect(exported.contains("qualityCheck: treeStructure"))
        #expect(exported.contains("qualityCheck: nodeCountRange(Item, 1, 10)"))
        #expect(exported.contains("transform: identity"))

        // Re-parse
        let parser2 = VGraphParser(logger: NoOpLogger())
        let graph2 = try parser2.parse(source: exported)

        let storedChecks = graph2.notationDefinition.declaredQualityChecks.map { $0.specString }
        #expect(storedChecks.contains("treeStructure"))
        #expect(storedChecks.contains("nodeCountRange(Item, 1, 10)"))
        #expect(graph2.notationDefinition.declaredTransforms == ["identity"])
    }

    @Test
    func testVNotationUnknownQualityCheckThrows() throws {
        let spec = QualityCheckSpec(name: "nonExistentCheck")
        #expect(throws: VError.self) {
            _ = try QualityCheckRegistry.resolve(spec)
        }
    }

    @Test
    func testVNotationUnknownTransformThrows() throws {
        #expect(throws: VError.self) {
            _ = try TransformRegistry.resolve(name: "nonExistentTransform")
        }
    }

    @Test
    func testQualityCheckSpecParsing() {
        // Simple name
        let simple = QualityCheckSpec.parse("treeStructure")
        #expect(simple.name == "treeStructure")
        #expect(simple.params.isEmpty)

        // With params
        let withParams = QualityCheckSpec.parse("nodeCountRange(Battle, 1, 20)")
        #expect(withParams.name == "nodeCountRange")
        #expect(withParams.params == ["Battle", "1", "20"])

        // Round-trip
        #expect(withParams.specString == "nodeCountRange(Battle, 1, 20)")
        #expect(simple.specString == "treeStructure")
    }

    @Test
    func testThatHadProblems() throws {
        let input = """
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
        let graph = try parser.parse(source: input)

        let report = Notations.analyzeQuality(graph: graph)
        // The base GoalTree csfCount check should NOT run (replaced by explicit checks).
        // GoalTree's csfCount would flag "1 CSF, recommended 3-5" as info.
        let csfMessages = report.infos.filter { $0.message.contains("Critical Success Factor") }
        #expect(csfMessages.isEmpty)
    }

    @Test
    func testThatHadProblemsII() throws {
        let input = """
                
                vgraph ConceptMap: ConceptMap "ConceptMap Meta Model" {
                    node _meta_Concept: Concept "Concept"
                    node _meta_EmphasizedConcept: EmphasizedConcept "EmphasizedConcept"
                    node _meta_Relation: Relation "Relation"
                    edge _meta_Concept -> _meta_Relation
                    edge _meta_EmphasizedConcept -> _meta_Relation
                    edge _meta_Relation -> _meta_Concept
                    edge _meta_Relation -> _meta_EmphasizedConcept
                }
            """

        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: input)

        let report = Notations.analyzeQuality(graph: graph)
        // The base GoalTree csfCount check should NOT run (replaced by explicit checks).
        // GoalTree's csfCount would flag "1 CSF, recommended 3-5" as info.
        let csfMessages = report.infos.filter { $0.message.contains("Critical Success Factor") }
        #expect(csfMessages.isEmpty)
    }
}

// MARK: - Arithmetic Full Cycle Tests

/// Four equations covering every node and edge type. `four` is reused as an operand
/// across three of them, exercising outDegreeMax being unbounded on the operand edges.
let arithmeticInput = """
    vgraph arithmeticDemo: Arithmetic "Four Simple Equations" {
        node seven: Number "7";
        node four: Number "4";
        node three: Number "3";
        node two: Number "2";
        node five: Number "5";
        node twelve: Number "12";

        node minusOp: Minus;
        node plusOp: Plus;
        node timesOp: Times;
        node divideOp: Divide;

        node eq1: Equals "3";
        node eq2: Equals "7";
        node eq3: Equals "12";
        node eq4: Equals "3";

        // 7 − 4 = 3
        edge seven -> minusOp: minus_first_operand;
        edge four -> minusOp: minus_second_operand;
        edge minusOp -> eq1: minus_result;

        // 2 + 5 = 7
        edge two -> plusOp: plus_first_operand;
        edge five -> plusOp: plus_second_operand;
        edge plusOp -> eq2: plus_result;

        // 3 × 4 = 12
        edge three -> timesOp: times_first_operand;
        edge four -> timesOp: times_second_operand;
        edge timesOp -> eq3: times_result;

        // 12 : 4 = 3
        edge twelve -> divideOp: divide_first_operand;
        edge four -> divideOp: divide_second_operand;
        edge divideOp -> eq4: divide_result;
    }
    """

@Suite("Arithmetic Full Cycle Tests")
struct ArithmeticFullCycleTests {

    typealias A = Notations.Arithmetic

    @Test
    func parseArithmeticGraph() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: arithmeticInput)

        #expect(graph.nodes.count == 14, "Expected 6 numbers + 4 operators + 4 equals = 14 nodes")
        #expect(graph.edges.count == 12, "Expected 8 operand edges + 4 result edges = 12 edges")

        let notationString: String = graph.notationName
        #expect(notationString == A.id.description, "Notation should be Arithmetic")

        let minusOp = Node(string: "minusOp")
        #expect(try graph.nodeType(for: minusOp) == A.NodeTypes.minus, "minusOp should be Minus type")

        let eq1 = Node(string: "eq1")
        #expect(try graph.nodeType(for: eq1) == A.NodeTypes.equals, "eq1 should be Equals type")
        try graph.ensure(node: eq1, attribute: Attributes.Node.label, isSameAs: "3")

        let seven = Node(string: "seven")
        #expect(try graph.nodeType(for: seven) == A.NodeTypes.number, "seven should be Number type")
        try graph.ensure(node: seven, attribute: Attributes.Node.label, isSameAs: "7")

        let edgeMinusResult = graph.edges.first { $0.from == minusOp && $0.to == eq1 }
        #expect(edgeMinusResult != nil, "Edge from minusOp to eq1 should exist")
        if let edge = edgeMinusResult {
            #expect(try graph.edgeType(for: edge.id) == A.EdgeTypes.minusResult, "Edge should be minus_result type")
        }

        // The operand side is deliberately unbounded.
        let four = Node(string: "four")
        let fourOutgoing = graph.edges.filter { $0.from == four }
        #expect(fourOutgoing.count == 3, "four should feed minus, times, and divide as an operand")

        let nodeTypes = Set(try graph.nodes.map { try graph.nodeType(for: $0) })
        for type in A.NodeTypes.all {
            #expect(nodeTypes.contains(type), "Missing node type \(type)")
        }
        let edgeTypes = Set(try graph.edges.map { try graph.edgeType(for: $0.id) })
        for type in A.EdgeTypes.all {
            #expect(edgeTypes.contains(type), "Missing edge type \(type)")
        }
    }

    @Test
    func testArithmeticCompleteGraphEquality() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        let g1 = try parser.parse(source: arithmeticInput)

        let exporter = VGLExporter()
        let exportedGraph = try exporter.export(graph: g1)

        let g2 = try parser.parse(source: exportedGraph)

        try assertGraphsAreEqual(g1, g2)
    }

    @Test
    func exportArithmeticToDotFormat() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: arithmeticInput)

        let exporter = DotExporter()
        let dotOutput = try exporter.export(graph: graph)

        #expect(dotOutput.hasPrefix("digraph"), "DOT should start with digraph")
        #expect(dotOutput.contains("minusOp"), "DOT should contain the Minus node")
        #expect(dotOutput.contains("eq1"), "DOT should contain the Equals node")
    }

    @Test
    func fullCycleParseAndExportArithmetic() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: arithmeticInput)

        let exporter = VGLExporter()
        let exportedVGraph = try exporter.export(graph: graph)

        #expect(!exportedVGraph.isEmpty, "Exported VGL should not be empty")
        #expect(exportedVGraph.contains("vgraph arithmeticDemo: Arithmetic"), "Exported VGL should contain graph declaration")
        #expect(exportedVGraph.contains("node minusOp: Minus"), "Exported VGL should contain the Minus node")
        #expect(exportedVGraph.contains("node eq1: Equals"), "Exported VGL should contain the Equals node")
        #expect(exportedVGraph.contains("edge"), "Exported VGL should contain edges")

        let graph2 = try parser.parse(source: exportedVGraph)

        #expect(graph2.nodes.count == graph.nodes.count, "Node count should be preserved")
        #expect(graph2.edges.count == graph.edges.count, "Edge count should be preserved")

        let notationString1: String = graph.notationName
        let notationString2: String = graph2.notationName
        #expect(notationString1 == notationString2, "Notation should be preserved")

        let seven = Node(string: "seven")
        let sevenLabel1: String = try graph.get(node: seven, attribute: Attributes.Node.label)
        let sevenLabel2: String = try graph2.get(node: seven, attribute: Attributes.Node.label)
        #expect(sevenLabel1 == sevenLabel2, "Node labels should be preserved")
    }

    /// Ties parsed VGL to the evaluator, which `ArithmeticEvaluationTests` covers directly.
    @Test
    func allFourEquationsEvaluateCorrect() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: arithmeticInput)

        let outcomes = ArithmeticEvaluation.evaluate(graph)
        #expect(outcomes.count == 4, "All four Equals nodes should have a resolvable outcome")
        // eq1: 7 − 4 = 3, eq2: 2 + 5 = 7, eq3: 3 × 4 = 12, eq4: 12 : 4 = 3
        let expectedValues: [String: Double] = ["eq1": 3, "eq2": 7, "eq3": 12, "eq4": 3]
        for (equalsId, value) in expectedValues {
            #expect(outcomes[Node(string: equalsId)] == .correct(value: value), "\(equalsId) should evaluate correct")
        }
    }
}

func dotColors(in dot: String) -> [String] {
    dot.split(separator: "\n")
        .filter { !$0.contains("->") }
        .compactMap { line in
            guard let r = line.range(of: "color=\"") else { return nil }
            let rest = line[r.upperBound...]
            guard let end = rest.firstIndex(of: "\"") else { return nil }
            return String(rest[..<end])
        }
}
