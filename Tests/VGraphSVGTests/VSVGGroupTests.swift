// Group markup snapshotted on its own, then checked to appear verbatim inside the
// full render — the second half is what catches the composition rebuilding it.

import Testing

@testable import App
@testable import VGLanguage
@testable import VGraph
@testable import VGraphSVG

struct VSVGGroupTests {

    func expectSnapshotAndAppearsInFullRender(
        _ graph: VGraph, darkMode: Bool = false,
        name: String = #function, sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let groups = try VSVGGroup.render(graph: graph, darkMode: darkMode).render()
        SVGSnapshot.verify(
            groups, named: SVGSnapshot.caseName("Group", name, darkMode ? "dark" : "light"),
            sourceLocation: sourceLocation)

        let full = try VSVGGraph.render(graph: graph, darkMode: darkMode, logger: TestLogger()).render()
        #expect(!groups.isEmpty, sourceLocation: sourceLocation)
        #expect(full.contains(groups), sourceLocation: sourceLocation)
    }

    // MARK: - Single group

    @Test func singleGroup() throws {
        let input = """
            vgraph myGraph: IBIS "Test Graph" {
                node q1: Question "Main question";
                group g1 "My Group" {
                    node a1: Answer "Answer in group";
                };
            }
            """
        let parser = VGraphParser(logger: TestLogger())
        var graph = try parser.parse(source: input)
        for group in graph.groups {
            graph = try graph.set(
                group: group,
                attribute: Attributes.Group.layoutedBounds.attribute(VRect(x: 80, y: 10, width: 200, height: 100)))
        }
        for node in graph.nodes {
            graph = try graph.set(node: node, attribute: Attributes.Node.layoutedPos.attribute(VPoint(x: 100, y: 100)))
            graph = try graph.set(node: node, attribute: Attributes.Node.layoutedSize.attribute(VSize(width: 80, height: 40)))
        }
        try expectSnapshotAndAppearsInFullRender(graph)
    }

    @Test func singleGroupWithoutALabelOmitsTheLabelElement() throws {
        // VGL has no syntax for an unlabeled group — the parser defaults a
        // group without an explicit label to the graph's own title. To
        // exercise the actually-empty-label path, set the attribute directly
        // (its own defaultValue is "").
        let input = """
            vgraph myGraph: IBIS "Test Graph" {
                node q1: Question "Q";
                group g1 "Group" {
                    node a1: Answer "A";
                };
            }
            """
        let parser = VGraphParser(logger: TestLogger())
        var graph = try parser.parse(source: input)
        for group in graph.groups {
            graph = try graph.set(
                group: group,
                attribute: Attributes.Group.layoutedBounds.attribute(VRect(x: 80, y: 10, width: 200, height: 100)))
            graph = try graph.set(group: group, attribute: Attributes.Group.label.attribute(""))
        }
        for node in graph.nodes {
            graph = try graph.set(node: node, attribute: Attributes.Node.layoutedPos.attribute(VPoint(x: 100, y: 100)))
            graph = try graph.set(node: node, attribute: Attributes.Node.layoutedSize.attribute(VSize(width: 80, height: 40)))
        }
        let ported = try VSVGGroup.render(graph: graph, darkMode: false).render()
        #expect(!ported.contains(SVGElementId.groupLabelClass))
        try expectSnapshotAndAppearsInFullRender(graph)
    }

    // MARK: - Nested groups

    @Test func nestedGroupsNestStructurally() throws {
        let input = """
            vgraph projectPlanning: IBIS "Software Project Planning" {
                node q1: Question "How should we approach this project?";
                group planning "Phase 1: Planning" {
                    node a1: Answer "Start with thorough planning";
                    group sub "Sub-phase" {
                        node a2: Answer "Nested answer";
                    };
                };
            }
            """
        let parser = VGraphParser(logger: TestLogger())
        var graph = try parser.parse(source: input)
        let outerBounds = VRect(x: 50, y: 50, width: 400, height: 400)
        let innerBounds = VRect(x: 70, y: 100, width: 360, height: 330)
        for group in graph.groups {
            let bounds = group.id.id.contains("sub") ? innerBounds : outerBounds
            graph = try graph.set(group: group, attribute: Attributes.Group.layoutedBounds.attribute(bounds))
        }
        for node in graph.nodes {
            graph = try graph.set(node: node, attribute: Attributes.Node.layoutedPos.attribute(VPoint(x: 100, y: 100)))
            graph = try graph.set(node: node, attribute: Attributes.Node.layoutedSize.attribute(VSize(width: 80, height: 40)))
        }

        try expectSnapshotAndAppearsInFullRender(graph)

        // Real parent/child nesting, not two siblings.
        let ported = try VSVGGroup.render(graph: graph, darkMode: false).render()
        guard let outerOpen = ported.range(of: "<g id=\"\(SVGElementId.group(graph.groups.first { $0.id.id.contains("planning") }!.id.id))\""),
            let innerOpen = ported.range(of: "<g id=\"\(SVGElementId.group(graph.groups.first { $0.id.id.contains("sub") }!.id.id))\"")
        else {
            Issue.record("expected both group ids in the ported output")
            return
        }
        #expect(outerOpen.lowerBound < innerOpen.lowerBound)
        #expect(ported.contains("depth-0"))
        #expect(ported.contains("depth-1"))
    }

    @Test func everyOpenedGroupTagIsClosed() throws {
        let input = """
            vgraph deepNesting: IBIS "Deep Nesting Test" {
                node root: Question "Root question";
                group level1 "Level 1" {
                    node n1: Answer "L1";
                    group level2 "Level 2" {
                        node n2: Answer "L2";
                        group level3 "Level 3" {
                            node n3: Answer "L3";
                        };
                    };
                };
            }
            """
        let parser = VGraphParser(logger: TestLogger())
        var graph = try parser.parse(source: input)
        for (index, group) in graph.groups.enumerated() {
            graph = try graph.set(
                group: group,
                attribute: Attributes.Group.layoutedBounds.attribute(
                    VRect(x: Double(index) * 10, y: Double(index) * 10, width: 400 - Double(index) * 20, height: 400 - Double(index) * 20)))
        }
        for node in graph.nodes {
            graph = try graph.set(node: node, attribute: Attributes.Node.layoutedPos.attribute(VPoint(x: 100, y: 100)))
            graph = try graph.set(node: node, attribute: Attributes.Node.layoutedSize.attribute(VSize(width: 80, height: 40)))
        }

        let ported = try VSVGGroup.render(graph: graph, darkMode: false).render()
        #expect(ported.components(separatedBy: "<g").count == ported.components(separatedBy: "</g>").count)
        try expectSnapshotAndAppearsInFullRender(graph)
    }

    // MARK: - Zero-bounds divergence

    @Test func zeroBoundsGroupIsSkippedAsAWrapperNotEmittedAsAStrayCloseTag() throws {
        let input = """
            vgraph myGraph: IBIS "Test Graph" {
                node q1: Question "Q";
                group g1 "Unlaidout Group" {
                    node a1: Answer "A";
                };
            }
            """
        let parser = VGraphParser(logger: TestLogger())
        var graph = try parser.parse(source: input)
        // Deliberately not setting layoutedBounds: it defaults to VRect.zero.
        for node in graph.nodes {
            graph = try graph.set(node: node, attribute: Attributes.Node.layoutedPos.attribute(VPoint(x: 100, y: 100)))
            graph = try graph.set(node: node, attribute: Attributes.Node.layoutedSize.attribute(VSize(width: 80, height: 40)))
        }

        let ported = try VSVGGroup.render(graph: graph, darkMode: false).render()
        #expect(!ported.contains(SVGElementId.group(graph.groups[0].id.id)))
        #expect(ported.components(separatedBy: "<g").count == ported.components(separatedBy: "</g>").count)

        // The string renderer stranded an unmatched `</g>` here, because a skipped
        // group still closed. A tree cannot leave an element open.
        let full = try VSVGGraph.render(graph: graph, darkMode: false, logger: TestLogger()).render()
        #expect(full.components(separatedBy: "<g").count == full.components(separatedBy: "</g>").count)
    }

    // MARK: - Colour resolution

    @Test func defaultBorderAndBackgroundFlipWithDarkModeButExplicitOverridesDoNot() throws {
        let input = """
            vgraph myGraph: IBIS "Test Graph" {
                node q1: Question "Q";
                group g1 "Themed" {
                    node a1: Answer "A";
                };
            }
            """
        let parser = VGraphParser(logger: TestLogger())
        var graph = try parser.parse(source: input)
        for group in graph.groups {
            graph = try graph.set(
                group: group, attribute: Attributes.Group.layoutedBounds.attribute(VRect(x: 0, y: 0, width: 100, height: 100)))
        }
        for node in graph.nodes {
            graph = try graph.set(node: node, attribute: Attributes.Node.layoutedPos.attribute(VPoint(x: 50, y: 50)))
            graph = try graph.set(node: node, attribute: Attributes.Node.layoutedSize.attribute(VSize(width: 80, height: 40)))
        }

        try expectSnapshotAndAppearsInFullRender(graph, darkMode: false)
        try expectSnapshotAndAppearsInFullRender(graph, darkMode: true)

        let light = try VSVGGroup.render(graph: graph, darkMode: false).render()
        let dark = try VSVGGroup.render(graph: graph, darkMode: true).render()
        #expect(light.contains(SemanticColor.groupBorder.lightHex))
        #expect(dark.contains(SemanticColor.groupBorder.darkHex))
        #expect(!dark.contains(SemanticColor.groupBorder.lightHex))
    }

    @Test func explicitBorderColorOverrideIsHonoredInBothThemes() throws {
        let input = """
            vgraph myGraph: IBIS "Test Graph" {
                node q1: Question "Q";
                group g1 "Themed" {
                    node a1: Answer "A";
                };
            }
            """
        let parser = VGraphParser(logger: TestLogger())
        var graph = try parser.parse(source: input)
        let customBorder = VColor(hexString: "#334455")!
        for group in graph.groups {
            graph = try graph.set(
                group: group, attribute: Attributes.Group.layoutedBounds.attribute(VRect(x: 0, y: 0, width: 100, height: 100)))
            graph = try graph.set(group: group, attribute: Attributes.Group.borderColor.attribute(customBorder))
        }
        for node in graph.nodes {
            graph = try graph.set(node: node, attribute: Attributes.Node.layoutedPos.attribute(VPoint(x: 50, y: 50)))
            graph = try graph.set(node: node, attribute: Attributes.Node.layoutedSize.attribute(VSize(width: 80, height: 40)))
        }

        try expectSnapshotAndAppearsInFullRender(graph, darkMode: false)
        try expectSnapshotAndAppearsInFullRender(graph, darkMode: true)

        let light = try VSVGGroup.render(graph: graph, darkMode: false).render()
        let dark = try VSVGGroup.render(graph: graph, darkMode: true).render()
        #expect(light.contains("#334455"))
        #expect(dark.contains("#334455"), "an explicit override must not be theme-remapped")
    }

    @Test func solidBorderDashArrayOmitsTheAttribute() throws {
        let input = """
            vgraph myGraph: IBIS "Test Graph" {
                node q1: Question "Q";
                group g1 "Themed" {
                    node a1: Answer "A";
                };
            }
            """
        let parser = VGraphParser(logger: TestLogger())
        var graph = try parser.parse(source: input)
        for group in graph.groups {
            graph = try graph.set(
                group: group, attribute: Attributes.Group.layoutedBounds.attribute(VRect(x: 0, y: 0, width: 100, height: 100)))
            graph = try graph.set(group: group, attribute: Attributes.Group.borderDash.attribute(""))
        }
        for node in graph.nodes {
            graph = try graph.set(node: node, attribute: Attributes.Node.layoutedPos.attribute(VPoint(x: 50, y: 50)))
            graph = try graph.set(node: node, attribute: Attributes.Node.layoutedSize.attribute(VSize(width: 80, height: 40)))
        }
        let ported = try VSVGGroup.render(graph: graph, darkMode: false).render()
        #expect(!ported.contains("stroke-dasharray"))
        try expectSnapshotAndAppearsInFullRender(graph)
    }
}
