import Testing
import VGraph

@testable import App

@Suite("Node colour through the pipeline")
struct NodeColourInVGLTests {

    private func styled(_ vgl: String, node id: String) throws -> NodeStyleLayout? {
        let app = VGraphApplication(ports: ParseOnlyPorts(logger: NoOpLogger()))
        let graph = try DisplayPipeline.assembleNodeStyles(try app.parseGraph(vgl))
        return try? graph.get(node: Node(string: id), attribute: Attributes.Node.style)
    }

    /// `get(node:)` cannot answer this: it inherits the type's style, so every node
    /// reports one either way.
    private func hasOwnStyle(_ vgl: String, node id: String) throws -> Bool {
        let app = VGraphApplication(ports: ParseOnlyPorts(logger: NoOpLogger()))
        let graph = try DisplayPipeline.assembleNodeStyles(try app.parseGraph(vgl))
        return graph.getOwnAttributes(node: Node(string: id))[Attributes.Node.style.id] != nil
    }

    private func fills(_ layout: NodeStyleLayout?) -> [String] {
        guard let layout else { return [] }
        var found: [String] = []
        if let fill = layout.backgroundFill { found.append(fill.lightHex.lowercased()) }
        return found
    }

    /// C4 cards are `presetLayout` — the path that ignored every authored colour.
    @Test("color on a C4 node reaches the rendered fill")
    func colorOnPresetNode() throws {
        let vgl = """
            vgraph t: C4 "T" {
                node p: Person "Op";
                group s "Sys" {
                    node plain: Container "Plain";
                    node tinted: Container "Tinted" [color: "#b6e6bd"];
                };
                edge p -> plain "Uses";
                edge p -> tinted "Uses";
            }
            """
        #expect(fills(try styled(vgl, node: "tinted")).first?.hasPrefix("#b6e6bd") == true)
        #expect(fills(try styled(vgl, node: "plain")).first?.hasPrefix("#438dd5") == true)
    }

    @Test("a node without its own colour gets no per-node style")
    func untouchedNodeIsUnaffected() throws {
        let vgl = """
            vgraph t: C4 "T" {
                node p: Person "Op";
                group s "Sys" { node plain: Container "Plain"; };
                edge p -> plain "Uses";
            }
            """
        #expect(try !hasOwnStyle(vgl, node: "plain"))
    }

    @Test("text flips to dark on a pale fill")
    func textFlipsForContrast() throws {
        let vgl = """
            vgraph t: C4 "T" {
                node p: Person "Op";
                group s "Sys" {
                    node tinted: Container "Tinted" [color: "#b6e6bd"];
                };
                edge p -> tinted "Uses";
            }
            """
        let layout = try #require(try styled(vgl, node: "tinted"))
        #expect(!textColors(of: layout).contains { $0.isLight })
    }

    @Test("fontColor overrides the contrast rule")
    func fontColorWins() throws {
        let vgl = """
            vgraph t: C4 "T" {
                node p: Person "Op";
                group s "Sys" {
                    node tinted: Container "Tinted" [color: "#b6e6bd"; fontColor: "#7a0000"];
                };
                edge p -> tinted "Uses";
            }
            """
        let layout = try #require(try styled(vgl, node: "tinted"))
        #expect(textColors(of: layout).allSatisfy { $0.lightHex.lowercased().hasPrefix("#7a0000") })
    }

    @Test("an SVG colour keyword resolves to its fill")
    func namedColourResolves() throws {
        let vgl = """
            vgraph t: C4 "T" {
                node p: Person "Op";
                group s "Sys" { node n: Container "N" [color: cornflowerblue]; };
                edge p -> n "Uses";
            }
            """
        #expect(fills(try styled(vgl, node: "n")).first?.hasPrefix("#6495ed") == true)
    }

    /// Graphviz would accept this one; the domain deliberately does not.
    @Test("an X11-only name is rejected, not ignored")
    func x11OnlyNameIsRejected() throws {
        let vgl = """
            vgraph t: C4 "T" {
                node p: Person "Op";
                group s "Sys" { node n: Container "N" [color: chartreuse3]; };
                edge p -> n "Uses";
            }
            """
        #expect(throws: VError.self) { try styled(vgl, node: "n") }
    }

    private func textColors(of layout: NodeStyleLayout) -> [SemanticColor] {
        switch layout {
        case .nodeText(let c), .italicNodeText(let c), .typeLabel(_, _, let c),
            .subtitleText(_, let c), .circleContent(_, _, let c):
            return [c]
        case .padded(_, let inner), .sized(_, let inner), .background(_, let inner):
            return textColors(of: inner)
        case .vertical(let ls, _), .horizontal(let ls, _): return ls.flatMap { textColors(of: $0) }
        case .overlay(let base, let overlay): return textColors(of: base) + textColors(of: overlay)
        default: return []
        }
    }
}
