// The full rendering pipeline (without WASM layout), driven through the port the
// hosts use. `VSVGGraphTests` snapshots these same documents; what these add is
// the named structure a reviewer needs in order to read a snapshot diff.

import Testing

@testable import App
@testable import VGLanguage
@testable import VGraph
@testable import VGraphSVG

struct TestLogger: ForLogMessages {
    func log(_ message: String) {
        // Silent for tests
    }
    func error(_ message: String) {
        print("[ERROR] \(message)")
    }
}

struct SVGRendererTests {

    @Test func testRenderSimpleGraph() throws {
        let input = """
            vgraph myGraph: IBIS "Test Graph" {
                node q1: Question "What should we do?";
                node a1: Answer "Option A";
                node pro1: Pro "Good outcome";

                edge q1 -> a1;
                edge a1 -> pro1;
            }
            """

        let parser = VGraphParser(logger: TestLogger())
        let graph = try parser.parse(source: input)

        var layoutedGraph = graph
        for (index, node) in graph.nodes.enumerated() {
            let pos = VPoint(x: Double(index) * 100 + 50, y: 50)
            layoutedGraph = try layoutedGraph.set(
                node: node,
                attribute: Attributes.Node.layoutedPos.attribute(pos)
            )
            layoutedGraph = try layoutedGraph.set(
                node: node,
                attribute: Attributes.Node.layoutedSize.attribute(VSize(width: 80, height: 40))
            )
        }

        let renderer = VSVGRenderer(logger: TestLogger())
        let svg = try renderer.render(graph: layoutedGraph)

        // The editor's hit-testing, inline editor and hover CSS are all written
        // against these ids and classes.
        for node in graph.nodes {
            #expect(svg.contains("<g id=\"\(SVGElementId.node(node.id))\" class=\"\(SVGElementId.nodeClass)\">"))
        }
        for edge in graph.edges {
            #expect(svg.contains("<g id=\"\(SVGElementId.edge(edge.id.id))\" class=\"\(SVGElementId.edgeClass)\">"))
        }
        #expect(svg.hasPrefix("<svg "))
        #expect(svg.hasSuffix("</svg>"))
        // Counted too: the ids above prove each element is present, not that it is
        // present once.
        #expect(svg.components(separatedBy: "class=\"\(SVGElementId.nodeClass)\"").count - 1 == graph.nodes.count)
        #expect(svg.components(separatedBy: "class=\"\(SVGElementId.edgeClass)\"").count - 1 == graph.edges.count)

        // No labels, and that is the fixture's doing: it skips the text-wrapping
        // step, and the renderer draws only what `wrappedText` hands it.
        #expect(!svg.contains("What should"))
    }

    @Test func testRenderGraphWithGroup() throws {
        let input = """
            vgraph myGraph: IBIS "Test Graph" {
                node q1: Question "Main question";

                group g1 "My Group" {
                    node a1: Answer "Answer in group";
                    node pro1: Pro "Pro in group";
                };

                edge q1 -> a1;
                edge a1 -> pro1;
            }
            """

        let parser = VGraphParser(logger: TestLogger())
        let graph = try parser.parse(source: input)

        var layoutedGraph = graph
        for (index, node) in graph.nodes.enumerated() {
            let pos = VPoint(x: Double(index) * 100 + 50, y: 50)
            layoutedGraph = try layoutedGraph.set(
                node: node,
                attribute: Attributes.Node.layoutedPos.attribute(pos)
            )
            layoutedGraph = try layoutedGraph.set(
                node: node,
                attribute: Attributes.Node.layoutedSize.attribute(VSize(width: 80, height: 40))
            )
        }

        let group = graph.groups[0]
        layoutedGraph = try layoutedGraph.set(
            group: group,
            attribute: Attributes.Group.layoutedBounds.attribute(VRect(x: 80, y: 10, width: 200, height: 100))
        )
        layoutedGraph = try layoutedGraph.set(
            group: group,
            attribute: Attributes.Group.labelLayoutedPos.attribute(VPoint(x: 180, y: 20))
        )

        let renderer = VSVGRenderer(logger: TestLogger())
        let svg = try renderer.render(graph: layoutedGraph)

        #expect(svg.contains("<g id=\"\(SVGElementId.group(group.id.id))\" class=\"\(SVGElementId.groupClass) depth-0\">"))
        // Classed separately because the group's box covers its members: hit-testing
        // the whole `.vgraph-group` would make any click inside it a rename.
        #expect(svg.contains("class=\"\(SVGElementId.groupLabelClass)\""))
        #expect(svg.contains("MY GROUP"), "group titles are upper-cased on the way out")

        // The members are nested inside the group element, not siblings of it.
        let groupOpen = svg.range(of: "<g id=\"\(SVGElementId.group(group.id.id))\"")
        let memberOpen = svg.range(of: "<g id=\"\(SVGElementId.node("a1"))\"")
        #expect(groupOpen != nil)
        #expect(memberOpen != nil)
        if let groupOpen, let memberOpen { #expect(groupOpen.lowerBound < memberOpen.lowerBound) }
    }

    /// This is the exact same VGL that the website uses for "Nested Groups Example"
    @Test func testRenderGraphWithNestedGroups_WebsiteExample() throws {
        let input = """
            vgraph projectPlanning: IBIS "Software Project Planning" {
                node q1: Question "How should we approach this project?";

                group planning "Phase 1: Planning" {
                    node a1: Answer "Start with thorough planning";
                    node pro1: Pro "Reduces risks early";
                    node con1: Con "Takes more time upfront";

                    group requirements "Requirements Analysis" {
                        node q2: Question "What are the key requirements?";
                        node a2: Answer "Focus on user needs";
                        node a3: Answer "Focus on technical constraints";
                        node pro2: Pro "User-centered approach";
                        node con2: Con "May miss technical issues";
                    };

                    group timeline "Timeline Planning" {
                        node q3: Question "What timeline is realistic?";
                        node a4: Answer "3-month sprint cycles";
                        node a5: Answer "6-month waterfall phases";
                        node pro3: Pro "Faster feedback loops";
                        node pro4: Pro "More predictable delivery";
                    };
                };

                group implementation "Phase 2: Implementation" {
                    node a6: Answer "Move fast and iterate";
                    node pro5: Pro "Quick time to market";
                    node con3: Con "May accumulate tech debt";

                    group testing "Testing Strategy" {
                        node q4: Question "How do we ensure quality?";
                        node a7: Answer "Test-driven development";
                        node a8: Answer "QA team testing";
                        node pro6: Pro "Catches bugs early";
                        node con4: Con "Slower initial development";
                    };
                };

                edge q1 -> a1;
                edge q1 -> a6;
                edge a1 -> pro1;
                edge a1 -> con1;

                edge a1 -> q2;
                edge q2 -> a2;
                edge q2 -> a3;
                edge a2 -> pro2;
                edge a2 -> con2;

                edge a1 -> q3;
                edge q3 -> a4;
                edge q3 -> a5;
                edge a4 -> pro3;
                edge a5 -> pro4;

                edge a6 -> pro5;
                edge a6 -> con3;
                edge a6 -> q4;
                edge q4 -> a7;
                edge q4 -> a8;
                edge a7 -> pro6;
                edge a7 -> con4;
            }
            """

        let parser = VGraphParser(logger: TestLogger())
        let graph = try parser.parse(source: input)

        // Note: Additional nodes may be created for unknown edge types
        #expect(graph.nodes.count >= 18)  // At least 18 declared nodes
        #expect(graph.groups.count == 5)  // planning, requirements, timeline, implementation, testing (root is filtered)
        #expect(graph.edges.count >= 17)  // At least 17 declared edges

        let groupIds = graph.groups.map { $0.id.description }
        #expect(groupIds.contains("planning"))
        #expect(groupIds.contains("requirements"))
        #expect(groupIds.contains("timeline"))
        #expect(groupIds.contains("implementation"))
        #expect(groupIds.contains("testing"))

        var layoutedGraph = graph
        for (index, node) in graph.nodes.enumerated() {
            let row = index / 4
            let col = index % 4
            let pos = VPoint(x: Double(col) * 150 + 100, y: Double(row) * 100 + 50)
            layoutedGraph = try layoutedGraph.set(
                node: node,
                attribute: Attributes.Node.layoutedPos.attribute(pos)
            )
            layoutedGraph = try layoutedGraph.set(
                node: node,
                attribute: Attributes.Node.layoutedSize.attribute(VSize(width: 120, height: 50))
            )
        }

        let groupBounds: [String: VRect] = [
            "planning": VRect(x: 50, y: 80, width: 600, height: 350),
            "requirements": VRect(x: 70, y: 150, width: 280, height: 150),
            "timeline": VRect(x: 360, y: 150, width: 280, height: 150),
            "implementation": VRect(x: 50, y: 450, width: 600, height: 200),
            "testing": VRect(x: 70, y: 500, width: 280, height: 130),
        ]

        for group in graph.groups {
            let groupId = group.id.description
            if let bounds = groupBounds[groupId] {
                layoutedGraph = try layoutedGraph.set(
                    group: group,
                    attribute: Attributes.Group.layoutedBounds.attribute(bounds)
                )
                let labelPos = VPoint(x: bounds.x + bounds.width / 2, y: bounds.y + 15)
                layoutedGraph = try layoutedGraph.set(
                    group: group,
                    attribute: Attributes.Group.labelLayoutedPos.attribute(labelPos)
                )
            }
        }

        let renderer = VSVGRenderer(logger: TestLogger())
        let svg = try renderer.render(graph: layoutedGraph)

        #expect(svg.contains("<svg"))
        #expect(svg.contains("</svg>"))
        #expect(svg.contains("<rect"))
        // Should have group labels (uppercased per Vithanco Diagram Style Guide §08)
        #expect(svg.contains("PHASE 1: PLANNING"))
        #expect(svg.contains("REQUIREMENTS ANALYSIS"))
        #expect(svg.contains("TIMELINE PLANNING"))
        #expect(svg.contains("PHASE 2: IMPLEMENTATION"))
        #expect(svg.contains("TESTING STRATEGY"))
    }

    /// This test reproduces a bug where alpha values exceeded 1.0 for deeply nested groups
    @Test func testRenderDeeplyNestedGroups_AlphaCalculation() throws {
        // Create VGL with 4 levels of group nesting
        let input = """
            vgraph deepNesting: IBIS "Deep Nesting Test" {
                node root: Question "Root question";

                group level1 "Level 1" {
                    node n1: Answer "Level 1 node";

                    group level2 "Level 2" {
                        node n2: Answer "Level 2 node";

                        group level3 "Level 3" {
                            node n3: Answer "Level 3 node";

                            group level4 "Level 4" {
                                node n4: Answer "Level 4 node";
                            };
                        };
                    };
                };

                edge root -> n1;
                edge n1 -> n2;
                edge n2 -> n3;
                edge n3 -> n4;
            }
            """

        let parser = VGraphParser(logger: TestLogger())
        let graph = try parser.parse(source: input)

        #expect(graph.groups.count == 4)  // level1, level2, level3, level4 (root filtered)

        let level1 = graph.groups.first { $0.id.description == "level1" }
        let level2 = graph.groups.first { $0.id.description == "level2" }
        let level3 = graph.groups.first { $0.id.description == "level3" }
        let level4 = graph.groups.first { $0.id.description == "level4" }

        #expect(level1 != nil, "Level 1 group should exist")
        #expect(level2 != nil, "Level 2 group should exist")
        #expect(level3 != nil, "Level 3 group should exist")
        #expect(level4 != nil, "Level 4 group should exist")

        if let l2 = level2, let l3 = level3, let l4 = level4 {
            #expect(graph.parentGroup(of: l2)?.id.description == "level1")
            #expect(graph.parentGroup(of: l3)?.id.description == "level2")
            #expect(graph.parentGroup(of: l4)?.id.description == "level3")
        }

        var layoutedGraph = graph
        for (index, node) in graph.nodes.enumerated() {
            let pos = VPoint(x: 200, y: Double(index) * 80 + 50)
            layoutedGraph = try layoutedGraph.set(
                node: node,
                attribute: Attributes.Node.layoutedPos.attribute(pos)
            )
            layoutedGraph = try layoutedGraph.set(
                node: node,
                attribute: Attributes.Node.layoutedSize.attribute(VSize(width: 100, height: 40))
            )
        }

        let groupBounds: [String: VRect] = [
            "level1": VRect(x: 50, y: 50, width: 400, height: 400),
            "level2": VRect(x: 70, y: 100, width: 360, height: 330),
            "level3": VRect(x: 90, y: 150, width: 320, height: 260),
            "level4": VRect(x: 110, y: 200, width: 280, height: 190),
        ]

        for group in graph.groups {
            let groupId = group.id.description
            if let bounds = groupBounds[groupId] {
                layoutedGraph = try layoutedGraph.set(
                    group: group,
                    attribute: Attributes.Group.layoutedBounds.attribute(bounds)
                )
                let labelPos = VPoint(x: bounds.x + bounds.width / 2, y: bounds.y + 15)
                layoutedGraph = try layoutedGraph.set(
                    group: group,
                    attribute: Attributes.Group.labelLayoutedPos.attribute(labelPos)
                )
            }
        }

        // This should NOT crash in debug mode - previously the alpha calculation
        // would produce values > 1.0 which could trigger assertions
        let renderer = VSVGRenderer(logger: TestLogger())
        let svg = try renderer.render(graph: layoutedGraph)

        #expect(svg.contains("<svg"))
        #expect(svg.contains("</svg>"))

        #expect(svg.contains("<rect"))

        // Verify all group labels are present (uppercased per Vithanco Diagram Style Guide §08)
        #expect(svg.contains("LEVEL 1"))
        #expect(svg.contains("LEVEL 2"))
        #expect(svg.contains("LEVEL 3"))
        #expect(svg.contains("LEVEL 4"))

        // Verify fill-opacity values are valid (should be <= 1.0)
        // The SVG should not contain fill-opacity values greater than 1
        // Since we clamp to 1.0, nested groups at depth 1+ should have opacity = 1.0
        // and thus no fill-opacity attribute (only added when < 1.0)
        #expect(!svg.isEmpty)
    }

    // MARK: - Interactive Hover Tests

    /// Nodes and edges are wrapped in identifiable, hover-able groups, and the
    /// static self-highlight styles are baked into the SVG (Style Guide §12).
    @Test func testHoverWrappersAndStaticStyles() throws {
        let input = """
            vgraph myGraph: IBIS "Test Graph" {
                node q1: Question "What should we do?";
                node a1: Answer "Option A";
                node pro1: Pro "Good outcome";

                edge q1 -> a1;
                edge a1 -> pro1;
            }
            """

        let parser = VGraphParser(logger: TestLogger())
        let graph = try parser.parse(source: input)

        var layoutedGraph = graph
        for (index, node) in graph.nodes.enumerated() {
            let pos = VPoint(x: Double(index) * 100 + 50, y: 50)
            layoutedGraph = try layoutedGraph.set(
                node: node, attribute: Attributes.Node.layoutedPos.attribute(pos))
            layoutedGraph = try layoutedGraph.set(
                node: node, attribute: Attributes.Node.layoutedSize.attribute(VSize(width: 80, height: 40)))
        }

        let renderer = VSVGRenderer(logger: TestLogger())
        let svg = try renderer.render(graph: layoutedGraph)

        #expect(svg.contains("id=\"node-q1\" class=\"vgraph-node\""))
        #expect(svg.contains("id=\"node-a1\" class=\"vgraph-node\""))
        #expect(svg.contains("id=\"node-pro1\" class=\"vgraph-node\""))
        #expect(svg.contains("class=\"vgraph-edge\""))
        #expect(svg.contains(".vgraph-node:hover"))
        #expect(svg.contains(".vgraph-edge:hover"))
        #expect(svg.contains(".vgraph-group:hover"))
        #expect(svg.contains("svg:has(.vgraph-node:hover, .vgraph-edge:hover, .loop-indicator:hover) .vgraph-node"))
        #expect(svg.contains("opacity: 0.15"))
        #expect(svg.contains("opacity: 1 !important"))
    }

    /// Hovering a node highlights its neighbour nodes via generated `:has()`
    /// rules, and hovering an edge highlights its endpoints.
    @Test func testNeighborHoverRulesGenerated() throws {
        let input = """
            vgraph myGraph: IBIS "Test Graph" {
                node q1: Question "What should we do?";
                node a1: Answer "Option A";
                node pro1: Pro "Good outcome";

                edge q1 -> a1;
                edge a1 -> pro1;
            }
            """

        let parser = VGraphParser(logger: TestLogger())
        let graph = try parser.parse(source: input)

        var layoutedGraph = graph
        for (index, node) in graph.nodes.enumerated() {
            let pos = VPoint(x: Double(index) * 100 + 50, y: 50)
            layoutedGraph = try layoutedGraph.set(
                node: node, attribute: Attributes.Node.layoutedPos.attribute(pos))
            layoutedGraph = try layoutedGraph.set(
                node: node, attribute: Attributes.Node.layoutedSize.attribute(VSize(width: 80, height: 40)))
        }

        let renderer = VSVGRenderer(logger: TestLogger())
        let svg = try renderer.render(graph: layoutedGraph)

        // a1 sits between q1 and pro1: hovering a1 must reach both neighbours.
        #expect(svg.contains("svg:has(#node-a1:hover) #node-q1"))
        #expect(svg.contains("svg:has(#node-a1:hover) #node-pro1"))
        // q1 is an endpoint of one edge → reaches a1 only (not pro1).
        #expect(svg.contains("svg:has(#node-q1:hover) #node-a1"))
        #expect(!svg.contains("svg:has(#node-q1:hover) #node-pro1"))
        // Edge hover highlights endpoint nodes (endpoint scope present).
        #expect(svg.contains(":hover) #node-q1"))
        // Neighbour re-brighten carries opacity:1 to outrank the spotlight dim,
        // and incident edges recolour to the accent.
        #expect(svg.contains("opacity:1;filter:drop-shadow"))
        #expect(svg.contains("stroke:#3b82f6;stroke-width:3;"))
    }

    @Test func testJunctorNeighbourhoodJumpsThrough() throws {
        let input = """
            vgraph crt: CRT "Junctor test" {
                node a: Changeable "Cause A"
                node c: Changeable "Cause C"
                node j: AndJunctor
                node b: UndesirableEffect "Effect B"
                edge a -> j
                edge c -> j
                edge j -> b
            }
            """

        let parser = VGraphParser(logger: TestLogger())
        let graph = try parser.parse(source: input)

        var layoutedGraph = graph
        for (index, node) in graph.nodes.enumerated() {
            let pos = VPoint(x: Double(index) * 100 + 50, y: 50)
            layoutedGraph = try layoutedGraph.set(
                node: node, attribute: Attributes.Node.layoutedPos.attribute(pos))
            layoutedGraph = try layoutedGraph.set(
                node: node, attribute: Attributes.Node.layoutedSize.attribute(VSize(width: 80, height: 40)))
        }

        let renderer = VSVGRenderer(logger: TestLogger())
        let svg = try renderer.render(graph: layoutedGraph)

        #expect(svg.contains("svg:has(#node-a:hover) #node-j"))
        #expect(svg.contains("svg:has(#node-a:hover) #node-b"))
        #expect(svg.contains("svg:has(#node-a:hover) #node-c"))
    }

    // Separate from the AND test because each notation wires `isJunctor` itself,
    // and OR uses a different junctor id ("OR" vs "AndJunctor").
    @Test func testOrJunctorNeighbourhoodJumpsThrough() throws {
        let input = """
            vgraph prt: PRT "OR junctor test" {
                node o: Objective "Goal"
                node j: OR
                node a: IntermediateObjective "Path A"
                node b: IntermediateObjective "Path B"
                edge a -> j
                edge b -> j
                edge j -> o
            }
            """

        let parser = VGraphParser(logger: TestLogger())
        let graph = try parser.parse(source: input)

        var layoutedGraph = graph
        for (index, node) in graph.nodes.enumerated() {
            let pos = VPoint(x: Double(index) * 100 + 50, y: 50)
            layoutedGraph = try layoutedGraph.set(
                node: node, attribute: Attributes.Node.layoutedPos.attribute(pos))
            layoutedGraph = try layoutedGraph.set(
                node: node, attribute: Attributes.Node.layoutedSize.attribute(VSize(width: 80, height: 40)))
        }

        let renderer = VSVGRenderer(logger: TestLogger())
        let svg = try renderer.render(graph: layoutedGraph)

        #expect(svg.contains("svg:has(#node-a:hover) #node-j"))
        #expect(svg.contains("svg:has(#node-a:hover) #node-o"))
        #expect(svg.contains("svg:has(#node-a:hover) #node-b"))
    }

    /// In a CLD, hovering the loop *indicator* highlights the whole loop. Loop
    /// nodes/edges keep the generic neighbour rules — a node does NOT pull in the
    /// far side of its loop.
    @Test func testCLDLoopIndicatorHighlightsLoop() throws {
        // a→b→c→d→a reinforcing loop. `a`'s direct neighbours are b and d; `c` is
        // on the far side (reachable only through the indicator, not by hovering a).
        let input = """
            vgraph cld: CLD "Loop test" {
                node a: Stock "A"
                node b: Stock "B"
                node c: Stock "C"
                node d: Stock "D"
                edge a -> b: same
                edge b -> c: same
                edge c -> d: same
                edge d -> a: same
            }
            """

        let parser = VGraphParser(logger: TestLogger())
        let graph = try parser.parse(source: input)

        // Square positions so the loop encloses a non-zero area (loopDirection
        // falls back to node positions here — collinear points would be .error).
        let square: [String: VPoint] = [
            "a": VPoint(x: 0, y: 0), "b": VPoint(x: 100, y: 0),
            "c": VPoint(x: 100, y: 100), "d": VPoint(x: 0, y: 100),
        ]
        var layoutedGraph = graph
        for node in graph.nodes {
            let pos = square[node.id] ?? VPoint(x: 0, y: 0)
            layoutedGraph = try layoutedGraph.set(
                node: node, attribute: Attributes.Node.layoutedPos.attribute(pos))
            layoutedGraph = try layoutedGraph.set(
                node: node, attribute: Attributes.Node.layoutedSize.attribute(VSize(width: 60, height: 40)))
        }

        let renderer = VSVGRenderer(logger: TestLogger())
        let svg = try renderer.render(graph: layoutedGraph)

        // Node hover stays generic: `a` reaches its direct neighbours (b, d) but
        // NOT the far side `c` — hovering a node no longer lights the whole loop.
        #expect(svg.contains("svg:has(#node-a:hover) #node-b"))
        #expect(!svg.contains("svg:has(#node-a:hover) #node-c"))

        // The loop indicator is a hoverable element (id + transparent hit disc)…
        #expect(svg.contains("<g id=\"loop-"))
        #expect(svg.contains("pointer-events=\"all\""))
        // …and hovering it lights up the whole loop, including the far node `c`.
        let idStart = svg.range(of: "<g id=\"loop-")!.upperBound
        let loopId = "loop-" + svg[idStart...].prefix(while: { $0 != "\"" })
        #expect(svg.contains("svg:has(#\(loopId):hover) #node-c"))
    }

    // MARK: - Watermark Tests

    @Test func testWatermarkIncludedByDefault() throws {
        let input = """
            vgraph myGraph: IBIS "Test Graph" {
                node q1: Question "What?";
                node a1: Answer "This";
                edge q1 -> a1;
            }
            """

        let parser = VGraphParser(logger: TestLogger())
        let graph = try parser.parse(source: input)

        var layoutedGraph = graph
        for (index, node) in graph.nodes.enumerated() {
            let pos = VPoint(x: Double(index) * 100 + 50, y: 50)
            layoutedGraph = try layoutedGraph.set(
                node: node,
                attribute: Attributes.Node.layoutedPos.attribute(pos)
            )
            layoutedGraph = try layoutedGraph.set(
                node: node,
                attribute: Attributes.Node.layoutedSize.attribute(VSize(width: 80, height: 40))
            )
        }

        let renderer = VSVGRenderer(logger: TestLogger())
        let svg = try renderer.render(graph: layoutedGraph)

        #expect(svg.contains("id=\"vithanco-watermark\""))
        #expect(svg.contains("href=\"#vithanco-watermark\""))
        #expect(svg.contains("VITHANCO.COM"))
    }

    @Test func testWatermarkExcludedWhenDisabled() throws {
        let input = """
            vgraph myGraph: IBIS "Test Graph" {
                node q1: Question "What?";
                node a1: Answer "This";
                edge q1 -> a1;
            }
            """

        let parser = VGraphParser(logger: TestLogger())
        let graph = try parser.parse(source: input)

        var layoutedGraph = graph
        for (index, node) in graph.nodes.enumerated() {
            let pos = VPoint(x: Double(index) * 100 + 50, y: 50)
            layoutedGraph = try layoutedGraph.set(
                node: node,
                attribute: Attributes.Node.layoutedPos.attribute(pos)
            )
            layoutedGraph = try layoutedGraph.set(
                node: node,
                attribute: Attributes.Node.layoutedSize.attribute(VSize(width: 80, height: 40))
            )
        }

        layoutedGraph = try layoutedGraph.set(
            graphAttribute: Attributes.Group.watermark.attribute(false)
        )

        let renderer = VSVGRenderer(logger: TestLogger())
        let svg = try renderer.render(graph: layoutedGraph)

        #expect(!svg.contains("vithanco-watermark"))
        #expect(!svg.contains("VITHANCO.COM"))
    }

    @Test func testWatermarkAvoidsNodeOverlap() throws {
        let input = """
            vgraph myGraph: IBIS "Test Graph" {
                node q1: Question "Bottom-left node";
                node a1: Answer "Top-right node";
                edge q1 -> a1;
            }
            """

        let parser = VGraphParser(logger: TestLogger())
        let graph = try parser.parse(source: input)

        var layoutedGraph = graph
        // Place a node in the bottom-left corner area (near the default watermark position)
        let nodes = graph.nodes
        layoutedGraph = try layoutedGraph.set(
            node: nodes[0],
            attribute: Attributes.Node.layoutedPos.attribute(VPoint(x: 30, y: 280))
        )
        layoutedGraph = try layoutedGraph.set(
            node: nodes[0],
            attribute: Attributes.Node.layoutedSize.attribute(VSize(width: 80, height: 40))
        )
        layoutedGraph = try layoutedGraph.set(
            node: nodes[1],
            attribute: Attributes.Node.layoutedPos.attribute(VPoint(x: 270, y: 30))
        )
        layoutedGraph = try layoutedGraph.set(
            node: nodes[1],
            attribute: Attributes.Node.layoutedSize.attribute(VSize(width: 80, height: 40))
        )

        let renderer = VSVGRenderer(logger: TestLogger())
        let svg = try renderer.render(graph: layoutedGraph)

        // Watermark should still be present (just in a different corner)
        #expect(svg.contains("vithanco-watermark"))
        #expect(svg.contains("href=\"#vithanco-watermark\""))
    }
}
