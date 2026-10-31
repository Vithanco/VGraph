// `hasUserText` decides whether a command that creates a node of some type
// should ask the user for text. See ADR-0013.

import TestSupport
import Testing

@testable import VGraph

struct NodeLabelVisibilityTests {

    private func evaporatingCloud() throws -> VGraph {
        try Notations.EvaporatingCloud.addNotation(addTo: VGraph().defineStandardAttributes())
    }

    /// Evaporating Cloud is the discriminating notation: `conflict` is icon-only
    /// but is *not* a junctor, so an `isJunctor`-based rule would offer a label
    /// prompt for text the node can never display.
    @Test func iconOnlyTypesDisplayNoLabelEvenWhenNotJunctors() throws {
        let graph = try evaporatingCloud()

        #expect(graph.hasUserText(nodeType: Notations.EvaporatingCloud.NodeTypes.need))
        #expect(graph.hasUserText(nodeType: Notations.EvaporatingCloud.NodeTypes.want))

        #expect(!graph.hasUserText(nodeType: Notations.EvaporatingCloud.NodeTypes.orJunctor))
        #expect(!graph.hasUserText(nodeType: Notations.EvaporatingCloud.NodeTypes.conflict))
    }

    /// "User text" is narrower than "any text". A style may draw a category header
    /// or a type label, but the user authors neither, so neither makes the node
    /// editable — the distinction the name rests on.
    @Test func textBakedIntoTheStyleIsNotUserText() {
        let ink = SemanticColor(id: "test.ink", lightHex: "#000000")
        let font = VFont(size: 11)

        #expect(NodeStyleLayout.nodeText(color: ink).hasUserText)
        #expect(NodeStyleLayout.italicNodeText(color: ink).hasUserText)

        #expect(!NodeStyleLayout.typeLabel(text: "Container", font: font, color: ink).hasUserText)
        #expect(!NodeStyleLayout.subtitleText(text: "a subtitle", color: ink).hasUserText)
        #expect(
            !NodeStyleLayout.categoryHeader(
                text: "Person", font: font, backgroundColor: ink, textColor: ink
            ).hasUserText)
        #expect(!NodeStyleLayout.empty.hasUserText)

        // Found by walking the tree, not by inspecting the outermost case.
        #expect(NodeStyleLayout.padded(VEdgeInsets(), .nodeText(color: ink)).hasUserText)
    }
}
