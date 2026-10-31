import Foundation
import TestSupport
import Testing

@testable import App
@testable import VGLanguage
@testable import VGraph
@testable import VGraphvizLib

@Suite("Export to Dot testing")
struct ExportToDotTests {

    @Test func testNodeShapeExportToGraphviz() async throws {
        // Full cycle test: Parse VGraph string -> Extract shapes -> Export to DOT
        let vgraphInput = """
            vgraph testGraph: IBIS "Test Graph" {
                node node1: Question "Circle Node";
                node node2: Answer "Point Node";
            }
            """

        let app = VGraphTestApp()
        var graph = try app.parseGraph(vgraphInput)

        // Manually set the node styles with shapes (simulating what would come from notation)
        let node1 = Node(string: "node1")
        let node2 = Node(string: "node2")

        let circleStyle = NodeStyleLayout.background(
            .solid(shape: .circle, color: .literal(VColor.blue)),
            .nodeText(color: .literal(VColor.white))
        )
        let nodeType1 = try graph.nodeType(for: node1)
        graph = try graph.set(
            nodeType: nodeType1,
            def: Attributes.Node.style,
            value: circleStyle
        )

        let pointStyle = NodeStyleLayout.background(
            .clear(shape: .point),
            .empty
        )
        let nodeType2 = try graph.nodeType(for: node2)
        graph = try graph.set(
            nodeType: nodeType2,
            def: Attributes.Node.style,
            value: pointStyle
        )

        // Styles are set directly above, so mark assembleNodeStyles satisfied
        // rather than running it, then extract shapes.
        graph = try graph.marking([.assembleNodeStyles])
        graph = try DisplayPipeline.extractNodeShape(graph)

        let node1Shape: NodeShape = try graph.get(node: node1, attribute: Attributes.Node.shape)
        #expect(node1Shape == .circle)

        let node2Shape: NodeShape = try graph.get(node: node2, attribute: Attributes.Node.shape)
        #expect(node2Shape == .point)

        // For DOT export to include shapes, we need to run the layout step as part of the pipeline
        // Since we can't easily hook into the app's pipeline, let's just export directly
        let exporter = DotExporter()
        let dotOutputDirect = try exporter.export(graph: graph)

        #expect(dotOutputDirect.contains("node1"))
        #expect(dotOutputDirect.contains("shape=\"circle\""))

        #expect(dotOutputDirect.contains("node2"))
        #expect(dotOutputDirect.contains("shape=\"point\""))

    }

    @Test func testArrayOfStringsExportToGraphviz() async throws {
        // Test that an array of strings is exported as newline-separated text without brackets
        // Uses wrappedText (maps to "label" in DOT) which is a [String] attribute
        let vgraphInput = """
            vgraph testGraph: IBIS "Test Graph" {
                node testNode: Question "Test Node";
            }
            """
        let app = VGraphTestApp()
        var graph = try app.parseGraph(vgraphInput)

        let node = Node(string: "testNode")

        let testStrings = ["First line", "Second line", "Third line"]
        graph =
            try graph
            .set(node: node, attribute: try Attributes.Node.wrappedText.attribute(testStrings))

        let exporter = DotExporter()
        let dotOutput = try exporter.export(graph: graph)

        #expect(dotOutput.contains("testNode"))
        #expect(dotOutput.contains("label=\"First line\\nSecond line\\nThird line\""))

        #expect(!dotOutput.contains("[First"))
        #expect(!dotOutput.contains("line]"))

    }

    @Test func testEmptyArrayOfStringsExportToGraphviz() async throws {
        // Test that an empty array of strings is exported as empty string
        // Uses wrappedText (maps to "label" in DOT) which is a [String] attribute
        let vgraphInput = """
            vgraph testGraph: IBIS "Test Graph" {
                node testNode: Question "Test Node";
            }
            """
        let app = VGraphTestApp()
        var graph = try app.parseGraph(vgraphInput)

        let node = Node(string: "testNode")

        graph =
            try graph
            .set(node: node, attribute: try Attributes.Node.wrappedText.attribute([]))

        let exporter = DotExporter()
        let dotOutput = try exporter.export(graph: graph)

        #expect(dotOutput.contains("testNode"))
        #expect(dotOutput.contains("label=\"\""))

    }

    @Test func testLayoutDirectionExportToGraphviz() async throws {
        let vgraphInput = """
            vgraph testGraph: IBIS "Test Graph" {
                node n1: Question "Node 1";
                node n2: Answer "Node 2";
                edge n1 -> n2: answered_by;
            }
            """
        let app = VGraphTestApp()
        var graph = try app.parseGraph(vgraphInput)

        let testCases: [(LayoutDirection, String)] = [
            (.topToBottom, "TB"),
            (.leftToRight, "LR"),
            (.bottomToTop, "BT"),
            (.rightToLeft, "RL"),
        ]

        for (direction, expectedRankdir) in testCases {
            graph = try graph.set(graphAttribute: Attributes.Group.layoutDirection.attribute(direction))

            let exporter = DotExporter()
            let dotOutput = try exporter.export(graph: graph)

            // Top to bottom is IBIS's direction and Graphviz's default: setting it
            // changes nothing, so nothing need be written (ADR-0030).
            let emitted = dotOutput.contains("rankdir=\"\(expectedRankdir)\"")
            let isDefault = direction == Attributes.Group.layoutDirection.defaultValue
            #expect(
                emitted || (isDefault && !dotOutput.contains("rankdir=")),
                "Expected rankdir=\"\(expectedRankdir)\" for \(direction.readableName)")

        }
    }

    @Test func testOnlyAttributesInTranslationTableAreExported() async throws {
        // Custom attribute not in DotExporter's translation table
        let customAttr = TypedAttributeDefinition<String>(
            id: "test.custom",
            name: "Custom Attribute",
            description: "This attribute is not in the Graphviz translation table",
            defaultValue: "default",
            target: .node
        )

        let vgraphInput = """
            vgraph testGraph: IBIS "Test Graph" {
                node testNode: Question "Test Node";
            }
            """
        let app = VGraphTestApp()
        var graph = try app.parseGraph(vgraphInput)

        let node = Node(string: "testNode")

        // Add custom attribute and set tooltip (which IS in the translation table)
        graph =
            try graph
            .define(customAttr)
            .set(node: node, attribute: try customAttr.attribute("not_exported_value"))
            .set(node: node, attribute: try Attributes.Node.tooltip.attribute("exported_tooltip"))

        let exporter = DotExporter()
        let dotOutput = try exporter.export(graph: graph)

        #expect(
            dotOutput.contains("tooltip=\"exported_tooltip\""),
            "Attribute in translation table should be exported")

        #expect(
            !dotOutput.contains("not_exported_value"),
            "Attribute not in translation table should NOT be exported")

    }

    @Test func testGroupAttributesAreExported() async throws {
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
        let app = VGraphTestApp()
        let graph = try app.parseGraph(vgraphInput)

        let exporter = DotExporter()
        let dotOutput = try exporter.export(graph: graph)

        #expect(dotOutput.contains("subgraph cluster_testGroup"), "Group declaration should exist")

        #expect(dotOutput.contains("style=\"filled\""), "Group style attribute should be exported")
        #expect(dotOutput.contains("bgcolor=\"lightblue\""), "Group color attribute should be exported")
        #expect(dotOutput.contains("label=\"Test Group Label\""), "Group label should be exported")

    }

    @Test func testNodesAreInsideTheirGroups() async throws {
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
        let app = VGraphTestApp()
        let graph = try app.parseGraph(vgraphInput)

        let exporter = DotExporter()
        let dotOutput = try exporter.export(graph: graph)

        let lines = dotOutput.components(separatedBy: "\n")

        guard let groupAStart = lines.firstIndex(where: { $0.contains("subgraph cluster_groupA") }) else {
            Issue.record("subgraph groupA not found")
            return
        }
        guard let groupAEnd = lines[groupAStart...].firstIndex(where: { $0.trimmed() == "}" }) else {
            Issue.record("groupA closing brace not found")
            return
        }

        let groupABlock = lines[groupAStart...groupAEnd].joined(separator: "\n")
        #expect(groupABlock.contains("a1"), "Node a1 should be inside groupA block")
        #expect(groupABlock.contains("a2"), "Node a2 should be inside groupA block")
        #expect(!groupABlock.contains("b1 "), "Node b1 should NOT be inside groupA block")
        #expect(!groupABlock.contains("root"), "Root node should NOT be inside groupA block")

        guard let groupBStart = lines.firstIndex(where: { $0.contains("subgraph cluster_groupB") && !$0.contains("groupB_nested") }) else {
            Issue.record("subgraph groupB not found")
            return
        }
        guard let groupBEnd = lines[groupBStart...].lastIndex(where: { $0.trimmed() == "}" }) else {
            Issue.record("groupB closing brace not found")
            return
        }

        let groupBBlock = lines[groupBStart...groupBEnd].joined(separator: "\n")
        #expect(groupBBlock.contains("b1 "), "Node b1 should be inside groupB block")
        #expect(groupBBlock.contains("subgraph cluster_groupB_nested"), "Nested group should be inside groupB block")
        #expect(groupBBlock.contains("b1_1"), "Node b1_1 should be inside groupB block (nested)")
        #expect(!groupBBlock.contains("a1"), "Node a1 should NOT be inside groupB block")

        // Verify root node is outside all groups (appears after all subgraphs close)
        let rootNodeLine = lines.firstIndex(where: { $0.contains("root") && $0.contains("[") })
        #expect(rootNodeLine != nil, "Root node should exist in output")
        if let rootLine = rootNodeLine {
            #expect(rootLine > groupAStart, "Root node should appear after groups start")
        }

    }

    @Test func testNestedGroupsWithAttributes() async throws {
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
        let app = VGraphTestApp()
        let graph = try app.parseGraph(vgraphInput)

        let exporter = DotExporter()
        let dotOutput = try exporter.export(graph: graph)

        #expect(dotOutput.contains("subgraph cluster_outer"), "Outer group should exist")

        let lines = dotOutput.components(separatedBy: "\n")
        guard let outerStart = lines.firstIndex(where: { $0.contains("subgraph cluster_outer") }) else {
            Issue.record("subgraph outer not found")
            return
        }

        guard let outerEnd = lines[outerStart...].lastIndex(where: { $0.trimmed() == "}" }) else {
            Issue.record("outer group closing brace not found")
            return
        }

        let outerBlock = lines[outerStart...outerEnd].joined(separator: "\n")

        #expect(outerBlock.contains("style=\"filled\""), "Outer group should have style attribute")
        #expect(outerBlock.contains("bgcolor=\"lightgray\""), "Outer group should have color attribute")
        #expect(outerBlock.contains("label=\"Outer Group\""), "Outer group should have label")

        #expect(outerBlock.contains("subgraph cluster_inner"), "Inner group should be nested inside outer group")

        #expect(outerBlock.contains("style=\"dashed\""), "Inner group should have style attribute")
        #expect(outerBlock.contains("bgcolor=\"lightblue\""), "Inner group should have color attribute")
        #expect(outerBlock.contains("label=\"Inner Group\""), "Inner group should have label")

        #expect(outerBlock.contains("o1"), "Outer node should be in outer group")
        #expect(outerBlock.contains("i1"), "Inner node should be in nested structure")

    }

    @Test func testGraphLevelPropertiesAreExported() async throws {
        let vgraphInput = """
            vgraph testGraph: IBIS "Test Graph" {
                rankdir: LR;
                fontcolor: darkblue;
                labeljust: l;

                node n1: Question "Node 1";
                node n2: Answer "Node 2";
            }
            """
        let app = VGraphTestApp()
        let graph = try app.parseGraph(vgraphInput)

        let exporter = DotExporter()
        let dotOutput = try exporter.export(graph: graph)

        #expect(dotOutput.contains("rankdir=\"LR\""), "Layout direction should be exported")
        #expect(dotOutput.contains("fontcolor=\"darkblue\""), "Font color should be exported")
        #expect(dotOutput.contains("labeljust=\"l\""), "Label justification should be exported")
        #expect(dotOutput.contains("label=\"\\nTest Graph\""), "Graph label should be exported with padding")

        let lines = dotOutput.components(separatedBy: "\n")
        let rankdirLine = lines.firstIndex(where: { $0.contains("rankdir=\"LR\"") })
        let firstNodeLine = lines.firstIndex(where: { $0.contains("n1") || $0.contains("n2") })

        if let rdLine = rankdirLine, let nodeLen = firstNodeLine {
            #expect(rdLine < nodeLen, "Graph properties should appear before nodes")
        }

    }

    @Test func testComplexGraphPropertiesInDot() async throws {
        let vgraphInput = """
            vgraph complexGraph: IBIS "Complex Test Graph" {
                rankdir: LR;
                fontcolor: darkblue;
                labeljust: l;

                node root1: Question "Root Question 1" [fontsize: 16];

                group groupA "Group A" {
                    style: filled;
                    color: lightblue;
                    node a1: Question "Node A1";
                };
            }
            """
        let app = VGraphTestApp()
        let graph = try app.parseGraph(vgraphInput)

        let exporter = DotExporter()
        let dotOutput = try exporter.export(graph: graph)

        #expect(dotOutput.contains("rankdir=\"LR\""), "Layout direction should be in DOT output")
        #expect(dotOutput.contains("fontcolor=\"darkblue\""), "Font color should be in DOT output")
        #expect(dotOutput.contains("labeljust=\"l\""), "Label justification should be in DOT output")

        #expect(dotOutput.contains("subgraph cluster_groupA"), "Group should be in DOT output")
        #expect(dotOutput.contains("style=\"filled\""), "Group style should be in DOT output")
        #expect(dotOutput.contains("bgcolor=\"lightblue\""), "Group color should be in DOT output")

    }

    @Test func testSubgroupsCanHaveOwnAttributesAndOverrideParent() async throws {
        // Test that subgroups can have their own attributes AND can override parent group attributes
        // This verifies that:
        // 1. Subgroups can have their own distinct attributes
        // 2. Subgroups can override the SAME attribute that a parent has (e.g., both have fontsize)
        // 3. The exported DOT contains the correct values for each group

        let vgraphInput = """
            vgraph testGraph: IBIS "Test Graph" {
                group parent "Parent Group" {
                    style: filled;
                    color: lightgray;
                    fontsize: 20;
                    fontcolor: red;

                    node p1: Question "Parent Node";

                    group child "Child Group" {
                        style: dashed;
                        color: lightblue;
                        fontsize: 12;
                        fontcolor: blue;

                        node c1: Answer "Child Node";

                        group grandchild "Grandchild Group" {
                            style: rounded;
                            color: lightyellow;
                            fontsize: 8;
                            fontcolor: green;

                            node g1: Question "Grandchild Node";
                        };
                    };
                };
            }
            """
        let app = VGraphTestApp()
        let graph = try app.parseGraph(vgraphInput)

        let exporter = DotExporter()
        let dotOutput = try exporter.export(graph: graph)

        let lines = dotOutput.components(separatedBy: "\n")

        guard let parentStart = lines.firstIndex(where: { $0.contains("subgraph cluster_parent") }) else {
            Issue.record("subgraph parent not found")
            return
        }

        guard let childStart = lines.firstIndex(where: { $0.contains("subgraph cluster_child") }) else {
            Issue.record("subgraph child not found")
            return
        }

        // Parent's own attributes are between parentStart and childStart
        let parentAttrLines = lines[parentStart..<childStart].joined(separator: "\n")

        #expect(parentAttrLines.contains("style=\"filled\""), "Parent should have style=filled")
        #expect(parentAttrLines.contains("bgcolor=\"lightgray\""), "Parent should have color=lightgray")
        #expect(parentAttrLines.contains("fontsize=\"20\""), "Parent should have fontsize=20")
        #expect(parentAttrLines.contains("fontcolor=\"red\""), "Parent should have fontcolor=red")
        #expect(parentAttrLines.contains("label=\"Parent Group\""), "Parent should have correct label")

        guard let grandchildStart = lines.firstIndex(where: { $0.contains("subgraph cluster_grandchild") }) else {
            Issue.record("subgraph grandchild not found")
            return
        }

        // Child's own attributes are between childStart and grandchildStart
        let childAttrLines = lines[childStart..<grandchildStart].joined(separator: "\n")

        #expect(childAttrLines.contains("style=\"dashed\""), "Child should have style=dashed (overriding parent's filled)")
        #expect(childAttrLines.contains("bgcolor=\"lightblue\""), "Child should have color=lightblue (overriding parent's lightgray)")
        #expect(childAttrLines.contains("fontsize=\"12\""), "Child should have fontsize=12 (overriding parent's 20)")
        #expect(childAttrLines.contains("fontcolor=\"blue\""), "Child should have fontcolor=blue (overriding parent's red)")
        #expect(childAttrLines.contains("label=\"Child Group\""), "Child should have correct label")

        guard let grandchildEnd = lines[grandchildStart...].firstIndex(where: { $0.trimmed() == "}" }) else {
            Issue.record("grandchild closing brace not found")
            return
        }

        let grandchildAttrLines = lines[grandchildStart...grandchildEnd].joined(separator: "\n")

        #expect(grandchildAttrLines.contains("style=\"rounded\""), "Grandchild should have style=rounded")
        #expect(grandchildAttrLines.contains("bgcolor=\"lightyellow\""), "Grandchild should have color=lightyellow")
        #expect(grandchildAttrLines.contains("fontsize=\"8\""), "Grandchild should have fontsize=8")
        #expect(grandchildAttrLines.contains("fontcolor=\"green\""), "Grandchild should have fontcolor=green")
        #expect(grandchildAttrLines.contains("label=\"Grandchild Group\""), "Grandchild should have correct label")

        let parentEnd = lines[parentStart...].lastIndex(where: { $0.trimmed() == "}" })!
        let parentBlock = lines[parentStart...parentEnd].joined(separator: "\n")
        #expect(parentBlock.contains("subgraph cluster_child"), "Child group should be nested inside parent")
        #expect(parentBlock.contains("subgraph cluster_grandchild"), "Grandchild group should be nested inside parent (transitively)")

        let childEnd = lines[childStart...].lastIndex(where: { line in
            // Find the closing brace that matches the child block
            // This is tricky because grandchild is nested - we need the second-to-last closing brace
            line.trimmed() == "}"
        })!
        let childBlock = lines[childStart...childEnd].joined(separator: "\n")
        #expect(childBlock.contains("subgraph cluster_grandchild"), "Grandchild group should be nested inside child")

        #expect(parentBlock.contains("p1"), "Node p1 should be in parent block")
        #expect(childBlock.contains("c1"), "Node c1 should be in child block")
        #expect(grandchildAttrLines.contains("g1"), "Node g1 should be in grandchild block")

    }

    @Test func testSubgroupAttributesNotInheritedFromParent() async throws {
        // Test that when a parent has an attribute but the child does NOT have that attribute,
        // the child's DOT block should NOT contain the parent's attribute value
        // (i.e., attributes are NOT inherited - each group only exports its own attributes)

        let vgraphInput = """
            vgraph testGraph: IBIS "Test Graph" {
                group parent "Parent Group" {
                    style: filled;
                    color: darkred;
                    fontsize: 24;

                    node p1: Question "Parent Node";

                    group child "Child Group" {
                        color: lightblue;

                        node c1: Answer "Child Node";
                    };
                };
            }
            """
        let app = VGraphTestApp()
        let graph = try app.parseGraph(vgraphInput)

        let exporter = DotExporter()
        let dotOutput = try exporter.export(graph: graph)

        let lines = dotOutput.components(separatedBy: "\n")

        guard let parentStart = lines.firstIndex(where: { $0.contains("subgraph cluster_parent") }) else {
            Issue.record("subgraph parent not found")
            return
        }

        guard let childStart = lines.firstIndex(where: { $0.contains("subgraph cluster_child") }) else {
            Issue.record("subgraph child not found")
            return
        }

        guard let childEnd = lines[childStart...].firstIndex(where: { $0.trimmed() == "}" }) else {
            Issue.record("child closing brace not found")
            return
        }

        // Get the child block content only (not including nested content)
        let childBlock = lines[childStart...childEnd].joined(separator: "\n")

        let parentAttrLines = lines[parentStart..<childStart].joined(separator: "\n")
        #expect(parentAttrLines.contains("style=\"filled\""), "Parent should have style=filled")
        #expect(parentAttrLines.contains("bgcolor=\"darkred\""), "Parent should have color=darkred")
        #expect(parentAttrLines.contains("fontsize=\"24\""), "Parent should have fontsize=24")

        // Child should have ONLY its own attribute (color=lightblue)
        // Child should NOT have parent's style or fontsize
        #expect(childBlock.contains("bgcolor=\"lightblue\""), "Child should have its own color=lightblue")
        #expect(childBlock.contains("label=\"Child Group\""), "Child should have its label")

        #expect(!childBlock.contains("style=\"filled\""), "Child should NOT inherit parent's style")
        #expect(!childBlock.contains("darkred"), "Child should NOT contain parent's color value")
        #expect(!childBlock.contains("fontsize=\"24\""), "Child should NOT inherit parent's fontsize")

    }

    @Test func testMultipleSiblingsGroupsHaveIndependentAttributes() async throws {
        // Test that multiple sibling groups at the same level have independent attributes
        // and don't affect each other

        let vgraphInput = """
            vgraph testGraph: IBIS "Test Graph" {
                group groupA "Group A" {
                    style: filled;
                    color: red;
                    fontsize: 16;

                    node a1: Question "Node A1";
                };

                group groupB "Group B" {
                    style: dashed;
                    color: blue;
                    fontsize: 12;

                    node b1: Answer "Node B1";
                };

                group groupC "Group C" {
                    style: rounded;
                    color: green;
                    fontsize: 20;

                    node c1: Question "Node C1";
                };
            }
            """
        let app = VGraphTestApp()
        let graph = try app.parseGraph(vgraphInput)

        let exporter = DotExporter()
        let dotOutput = try exporter.export(graph: graph)

        let lines = dotOutput.components(separatedBy: "\n")

        func findGroupBlock(named groupName: String) -> String? {
            guard let start = lines.firstIndex(where: { $0.contains("subgraph \(groupName)") }) else {
                return nil
            }
            guard let end = lines[start...].firstIndex(where: { $0.trimmed() == "}" }) else {
                return nil
            }
            return lines[start...end].joined(separator: "\n")
        }

        guard let groupABlock = findGroupBlock(named: "cluster_groupA") else {
            Issue.record("subgraph groupA not found")
            return
        }
        #expect(groupABlock.contains("style=\"filled\""), "Group A should have style=filled")
        #expect(groupABlock.contains("bgcolor=\"red\""), "Group A should have color=red")
        #expect(groupABlock.contains("fontsize=\"16\""), "Group A should have fontsize=16")
        #expect(groupABlock.contains("a1"), "Node a1 should be in Group A")

        guard let groupBBlock = findGroupBlock(named: "cluster_groupB") else {
            Issue.record("subgraph groupB not found")
            return
        }
        #expect(groupBBlock.contains("style=\"dashed\""), "Group B should have style=dashed")
        #expect(groupBBlock.contains("bgcolor=\"blue\""), "Group B should have color=blue")
        #expect(groupBBlock.contains("fontsize=\"12\""), "Group B should have fontsize=12")
        #expect(groupBBlock.contains("b1"), "Node b1 should be in Group B")

        guard let groupCBlock = findGroupBlock(named: "cluster_groupC") else {
            Issue.record("subgraph groupC not found")
            return
        }
        #expect(groupCBlock.contains("style=\"rounded\""), "Group C should have style=rounded")
        #expect(groupCBlock.contains("bgcolor=\"green\""), "Group C should have color=green")
        #expect(groupCBlock.contains("fontsize=\"20\""), "Group C should have fontsize=20")
        #expect(groupCBlock.contains("c1"), "Node c1 should be in Group C")

        // Verify groups don't contain each other's GROUP-level attributes
        // Note: We check for the specific group attribute format (with tab prefix) to avoid
        // false positives from node attributes that may have similar values
        #expect(!groupABlock.contains("\t\tstyle=\"dashed\""), "Group A should not have Group B's style")
        #expect(!groupABlock.contains("\t\tcolor=\"blue\""), "Group A should not have Group B's color")
        #expect(!groupBBlock.contains("\t\tstyle=\"filled\""), "Group B should not have Group A's style")
        #expect(!groupBBlock.contains("\t\tcolor=\"red\""), "Group B should not have Group A's color")
        #expect(!groupCBlock.contains("\t\tstyle=\"dashed\""), "Group C should not have Group B's style")

    }

    // MARK: - Graph label padding tests

    @Test func testGraphLabelNotDuplicated() async throws {
        let vgraphInput = """
            vgraph test: IBIS "My Graph" {
                node q1: Question "Q1";
            }
            """
        let app = VGraphTestApp()
        let graph = try app.parseGraph(vgraphInput)

        let exporter = DotExporter()
        let dotOutput = try exporter.export(graph: graph)

        // The label should appear exactly once as a graph attribute (with padding)
        let labelLines = dotOutput.components(separatedBy: "\n").filter {
            $0.trimmingCharacters(in: .whitespaces).hasPrefix("label=")
        }
        #expect(labelLines.count == 1, "Graph label should appear exactly once, got \(labelLines.count): \(labelLines)")
    }

    @Test func testBottomLabelGetsPaddingAbove() async throws {
        let vgraphInput = """
            vgraph test: IBIS "Bottom Label" {
                node q1: Question "Q1";
            }
            """
        let app = VGraphTestApp()
        let graph = try app.parseGraph(vgraphInput)

        let exporter = DotExporter()
        let dotOutput = try exporter.export(graph: graph)

        // Default labelloc is bottom → padding newline before the text
        #expect(dotOutput.contains("label=\"\\nBottom Label\""), "Bottom label should have \\n before text")
    }

    @Test func testTopLabelGetsPaddingBelow() async throws {
        let vgraphInput = """
            vgraph test: IBIS "Top Label" {
                labelloc: t;
                node q1: Question "Q1";
            }
            """
        let app = VGraphTestApp()
        let graph = try app.parseGraph(vgraphInput)

        let exporter = DotExporter()
        let dotOutput = try exporter.export(graph: graph)

        // labelloc=t → padding newline after the text
        #expect(dotOutput.contains("label=\"Top Label\\n\""), "Top label should have \\n after text")
    }

    @Test func testGroupLabelsAreNotPadded() async throws {
        let vgraphInput = """
            vgraph test: IBIS "Root" {
                group g1 "My Group" {
                    node q1: Question "Q1";
                };
            }
            """
        let app = VGraphTestApp()
        let graph = try app.parseGraph(vgraphInput)

        let exporter = DotExporter()
        let dotOutput = try exporter.export(graph: graph)

        // Group label should NOT have padding newlines
        #expect(dotOutput.contains("label=\"My Group\""), "Group label should not be padded")
        #expect(!dotOutput.contains("label=\"\\nMy Group\""), "Group label should not have \\n prefix")
        #expect(!dotOutput.contains("label=\"My Group\\n\""), "Group label should not have \\n suffix")
    }
}

/// DOT says what VGraph resolves, not only what someone set: a value equal to
/// VGraph's default is not stored (ADR-0030), yet Graphviz has defaults of its own.
@Suite("DOT says what VGraph resolves")
struct DotResolvedValuesTests {
    let type = NodeType("T")
    let n1 = Node("n1")
    let n2 = Node("n2")
    let link = EdgeType(string: "link", from: "T", to: "T")

    private func graph() throws(VError) -> VGraph {
        try VGraph()
            .add(nodeType: type).add(edgeType: link)
            .add(node: n1, type: type, group: Group(rawValue: rootGroup))
            .add(node: n2, type: type, group: Group(rawValue: rootGroup))
            .add(edge: Edge(string: "e1", from: "n1", to: "n2"), edgeType: link)
    }

    private func line(_ id: String, in dot: String) -> String {
        dot.split(separator: "\n").map(String.init).first { $0.trimmingWhitespace().hasPrefix(id + " ") } ?? ""
    }

    @Test("Given a node nobody gave a font, when it is laid out, then Graphviz measures it in Helvetica, DM Sans's stand-in")
    func anUnsetFontIsMeasuredInTheStandIn() throws {
        let dot = try DotExporter().export(graph: graph())
        #expect(line("n1", in: dot).contains("fontname=\"Helvetica\""))
        #expect(!dot.contains("DM Sans"), "Graphviz has no metrics for DM Sans and warns about every use of it")
    }

    @Test("Given a type that sets the default font, when its node is laid out, then the font still reaches Graphviz")
    func aFontEqualToTheDefaultStillReachesGraphviz() throws {
        let typed = try graph().set(nodeType: type, attribute: Attributes.Node.fontname.attribute(.dmSans))
        #expect(line("n1", in: try DotExporter().export(graph: typed)).contains("fontname=\"Helvetica\""))
    }

    @Test("Given a C4 person, when it is laid out, then Graphviz is asked for a box")
    func aPersonIsLaidOutAsABox() throws {
        let shaped = try graph().set(node: n1, attribute: Attributes.Node.shape.attribute(.person))
        let dot = try DotExporter().export(graph: shaped)
        #expect(line("n1", in: dot).contains("shape=\"box\""))
        #expect(!dot.contains("person"))
    }

    @Test("Given a node of fixed size, when it is laid out, then Graphviz is not asked to measure its text")
    func aFixedSizeNodeHasNoTextForGraphviz() throws {
        let sized = try graph()
            .set(node: n1, attribute: Attributes.Node.wrappedText.attribute(["a long label"]))
            .set(node: n1, attribute: Attributes.Node.fixedsize.attribute(true))
        let dot = try DotExporter().export(graph: sized)
        #expect(line("n1", in: dot).contains("label=\"\""))
        #expect(!dot.contains("a long label"))
    }

    @Test("Given an edge that is not to constrain ranks, when it is laid out, then Graphviz is told")
    func anUnconstrainingEdgeSaysSo() throws {
        let loose = try graph().set(edge: Edge.Id(string: "e1"), attribute: Attributes.Edge.constraint.attribute(false))
        #expect(try DotExporter().export(graph: loose).contains("constraint=\"false\""))
    }

    @Test("Given an edge with nothing set, when it is laid out, then Graphviz's own defaults apply")
    func anUnsetEdgeWritesNothingGraphvizAssumes() throws {
        let dot = try DotExporter().export(graph: graph())
        #expect(!dot.contains("constraint="))
        #expect(!dot.contains("arrowhead="))
        #expect(!dot.contains("arrowtail="))
    }
}
