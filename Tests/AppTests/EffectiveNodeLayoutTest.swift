// `VGraph.effectiveNodeLayout` and the `assembleNodeStyles` pipeline step must
// agree — the step delegates to it precisely so the derivation exists once.

import Testing
import VGLanguage
import VGraph

@testable import App

struct EffectiveNodeLayoutTest {

    /// The whole point of extracting the derivation: a command needs a node type's
    /// layout *before* the display pipeline has run, and must get the same answer
    /// the pipeline would later store. If these drift, `hasUserText` starts
    /// disagreeing with what is actually drawn.
    @Test func matchesWhatThePipelineStoresForEveryNotation() throws {
        for (name, entry) in NotationRegistry.entries {
            let graph = try VGraph().defineStandardAttributes().placing(entry.content, in: .builtin)
            let assembled = try DisplayPipeline.assembleNodeStyles(graph)

            for nodeType in graph.nodeTypes {
                let stored = try? assembled.get(nodeType: nodeType, attribute: Attributes.Node.style)
                #expect(
                    stored == graph.effectiveNodeLayout(for: nodeType),
                    "\(name).\(nodeType.id) disagrees")
            }
        }
    }
}
