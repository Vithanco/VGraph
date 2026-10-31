//
//  URLBadgeTests.swift
//  VGraphSVG
//
//  The badge that marks an element carrying a link, and follows it on a click.
//

import Testing

@testable import App
@testable import VGLanguage
@testable import VGraph
@testable import VGraphSVG

struct URLBadgeTests {

    /// Nodes need a position and a size, and a group needs bounds, before anything
    /// renders — normally Graphviz's job.
    /// `transformed` runs the display transforms first, folding among them, as the
    /// real pipeline does before layout.
    private func render(_ vgl: String, darkMode: Bool = false, transformed: Bool = false) throws -> String {
        let parsed = try VGraphParser(logger: TestLogger()).parse(source: vgl)
        let graph = transformed ? try TransformStep.pipeline(Notations.extensionSteps)(parsed) : parsed

        var layouted = graph
        var x = 50.0
        for node in graph.nodes {
            layouted = try layouted.set(node: node, attribute: Attributes.Node.layoutedPos.attribute(VPoint(x: x, y: 50)))
            layouted = try layouted.set(
                node: node, attribute: Attributes.Node.layoutedSize.attribute(VSize(width: 80, height: 40)))
            x += 120
        }
        for group in graph.groups where group.id.id != rootGroup {
            layouted = try layouted.set(
                group: group,
                attribute: Attributes.Group.layoutedBounds.attribute(
                    VRect(origin: VPoint(x: 0, y: 0), size: VSize(width: 300, height: 120))))
        }
        return try VSVGRenderer(logger: TestLogger()).render(graph: layouted, darkMode: darkMode)
    }

    private let linkedNode = """
        vgraph demo: ConceptMap "Demo" {
          node a: Concept "A" [url: "https://vithanco.com/docs"];
        }
        """

    /// The badge itself, not the class name — the `cursor: pointer` rule puts that
    /// in the stylesheet of every diagram, linked or not.
    private let anchor = "<a class=\"\(URLBadgeRenderer.cssClass)\""

    /// The badge's `<a>…</a>`, or nil when there is none.
    private func badgeMarkup(in svg: String) -> String? {
        guard let start = svg.range(of: anchor),
            let end = svg.range(of: "</a>", range: start.upperBound..<svg.endIndex)
        else { return nil }
        return String(svg[start.lowerBound..<end.upperBound])
    }

    /// Where the badge sits, read back from the chip it draws.
    private func badgeCenter(in svg: String) -> (x: Double, y: Double)? {
        guard let markup = badgeMarkup(in: svg),
            let x = attribute("x", in: markup), let y = attribute("y", in: markup),
            let side = attribute("width", in: markup)
        else { return nil }
        return (x + side / 2, y + side / 2)
    }

    private func attribute(_ name: String, in markup: String) -> Double? {
        guard let key = markup.range(of: "\(name)=\""),
            let close = markup.range(of: "\"", range: key.upperBound..<markup.endIndex)
        else { return nil }
        return Double(markup[key.upperBound..<close.lowerBound])
    }

    // MARK: - The badge itself

    /// A real `<a>`, not a shape the host has to wire up: one click follows the
    /// link in the editor, and the same SVG dropped on a page keeps working.
    @Test func aLinkedNodeCarriesAFollowableBadge() throws {
        let svg = try render(linkedNode)

        #expect(svg.contains(anchor))
        #expect(svg.contains("href=\"https://vithanco.com/docs\""))
        #expect(svg.contains("target=\"_blank\""))
        #expect(svg.contains("rel=\"noopener noreferrer\""))
    }

    /// Hovering has to say where the click will go, before it goes there.
    @Test func theBadgeNamesItsDestinationOnHover() throws {
        let svg = try render(linkedNode)

        #expect(svg.contains("<title>https://vithanco.com/docs</title>"))
    }

    /// The badge belongs to the element, so right-click still reaches the node
    /// (`closest('.vgraph-node')` walks up through the anchor).
    @Test func theBadgeSitsInsideTheElementItBelongsTo() throws {
        let svg = try render(linkedNode)

        let nodeStart = svg.range(of: "id=\"node-a\"")
        let badge = svg.range(of: anchor)
        #expect(nodeStart != nil)
        #expect(badge != nil)
        if let nodeStart, let badge {
            #expect(nodeStart.lowerBound < badge.lowerBound)
        }
    }

    @Test func anElementWithNoLinkGetsNoBadge() throws {
        let svg = try render(
            """
            vgraph demo: ConceptMap "Demo" {
              node a: Concept "A";
            }
            """)

        #expect(!svg.contains(anchor))
    }

    // MARK: - Where it sits

    /// The node is 80×40 centred on (50, 50), so its top-right corner is (90, 30).
    @Test func theNodeBadgeStraddlesTheTopRightCorner() throws {
        let center = badgeCenter(in: try render(linkedNode))

        #expect(center != nil)
        if let center {
            #expect(abs(center.x - 90) <= 4)
            #expect(abs(center.y - 30) <= 4)
        }
    }

    /// Bottom, not top: a group's title runs along the top from the left,
    /// uppercased and of unknowable width, so a top-right badge lands on the
    /// letters as soon as the group is narrow. Bounds here are 300×120 from the
    /// origin.
    @Test func theGroupBadgeStraddlesTheBottomRightCornerAwayFromTheTitle() throws {
        let svg = try render(
            """
            vgraph demo: ConceptMap "Demo" {
              group g1 "A Very Long Cluster Title Indeed" {
                url: "https://vithanco.com/group";
                node a: Concept "A";
              }
            }
            """)
        let center = badgeCenter(in: svg)

        #expect(center != nil)
        if let center {
            #expect(abs(center.x - 300) <= 4)
            #expect(abs(center.y - 120) <= 4)
        }
    }

    /// A link must not move anything. The badge is drawn from the element's bounds
    /// at render time rather than joining the node's style layout, which would
    /// resize the node — and so relayout the diagram — the moment one was added.
    @Test func addingALinkChangesNothingButTheBadge() throws {
        let plain = try render(
            """
            vgraph demo: ConceptMap "Demo" {
              node a: Concept "A";
            }
            """)
        let linked = try render(linkedNode)

        #expect(badgeMarkup(in: linked) != nil)
        if let markup = badgeMarkup(in: linked) {
            #expect(linked.replacingOccurrences(of: markup, with: "") == plain)
        }
    }

    /// The chip is a `<rect>`, and has to stay one: `SVGBuilder.hoverStyles`
    /// repaints every circle, ellipse and polygon inside a hovered edge, and a
    /// badge that turns blue with the line it sits on stops reading as a badge.
    @Test func theChipIsNotAShapeTheEdgeHoverRuleRepaints() throws {
        let markup = badgeMarkup(in: try render(linkedNode))

        #expect(markup != nil)
        if let markup {
            #expect(markup.contains("<rect"))
            #expect(!markup.contains("<circle"))
            #expect(!markup.contains("<ellipse"))
            #expect(!markup.contains("<polygon"))
        }
    }

    // MARK: - Every kind

    /// Nothing here has been through Graphviz, so the edge is drawn as the
    /// fallback straight line — which still has to show its link. The routed-spline
    /// path is covered by the browser suite, against a real layout.
    @Test func edgesAndGroupsCarryBadgesToo() throws {
        let svg = try render(
            """
            vgraph demo: ConceptMap "Demo" {
              group g1 "Cluster" {
                url: "https://vithanco.com/group";
                node a: Concept "A";
              }
              node r: Relation "leads to" [url: "https://vithanco.com/node"];
              edge a -> r [url: "https://vithanco.com/edge"];
            }
            """)

        #expect(svg.contains("href=\"https://vithanco.com/group\""))
        #expect(svg.contains("href=\"https://vithanco.com/node\""))
        #expect(svg.contains("href=\"https://vithanco.com/edge\""))
    }

    // MARK: - What must never be published

    /// The one that matters: a `javascript:` URL typed straight into the VGL would
    /// otherwise become a live script in every exported SVG, running as whatever
    /// page displays it. The commands sanitise on the way in; rendering sanitises
    /// again because hand-written VGL never passed through them.
    @Test func aDangerousLinkIsNeverRendered() throws {
        let svg = try render(
            """
            vgraph demo: ConceptMap "Demo" {
              node a: Concept "A" [url: "javascript:alert(1)"];
            }
            """)

        #expect(!svg.contains("javascript:"))
        #expect(!svg.contains(anchor))
    }

    /// An ampersand in a query string must not end the attribute — the SVG has to
    /// stay parseable as XML.
    @Test func theHrefIsXMLEscaped() throws {
        let svg = try render(
            """
            vgraph demo: ConceptMap "Demo" {
              node a: Concept "A" [url: "https://vithanco.com/s?a=1&b=2"];
            }
            """)

        #expect(svg.contains("href=\"https://vithanco.com/s?a=1&amp;b=2\""))
    }

    // MARK: - Appearance

    @Test func theBadgeFlipsWithTheTheme() throws {
        let light = try render(linkedNode)
        let dark = try render(linkedNode, darkMode: true)

        #expect(light.contains(SemanticColor.linkBadgeFill.lightHex))
        #expect(dark.contains(SemanticColor.linkBadgeFill.darkHex))
    }

    @Test func theBadgeLooksClickable() throws {
        let svg = try render(linkedNode)

        #expect(svg.contains(".\(URLBadgeRenderer.cssClass) { cursor: pointer;"))
    }

    /// A folded group is drawn from a stand-in node; the box is still the group, so
    /// the fold step carries the group's link across to it.
    @Test func aFoldedGroupKeepsItsBadge() throws {
        let svg = try render(
            """
            vgraph demo: ConceptMap "Demo" {
              folded group g1 "Cluster" {
                url: "https://vithanco.com/group";
                node a: Concept "A";
              }
            }
            """, transformed: true)

        #expect(svg.contains("id=\"group-g1\""), "the folded box itself is drawn")
        #expect(badgeMarkup(in: svg) != nil)
    }
}
