import Testing

@testable import VGraph

@Suite("Built-in notations' junctor icons")
struct NotationJunctorIconTests {

    @Test("Given every built-in notation, when its junctor and conflict types are drawn, then each icon is 28px square")
    func everyJunctorIconIsTheGuidesJunctorSize() throws {
        var sizes: [String: Double] = [:]
        for (name, entry) in NotationRegistry.entries {
            let graph = try VGraph().defineStandardAttributes().placing(entry.content, in: .builtin)
            for nodeType in graph.nodeTypes {
                guard let style: NodeStyle = try? graph.get(nodeType: nodeType, attribute: Attributes.Node.nodeStyle),
                    style == .iconOnly
                else { continue }
                let icon: IconInfo = try graph.get(nodeType: nodeType, attribute: Attributes.Node.iconInfo)
                sizes["\(name).\(nodeType.description)"] = icon.iconSize
            }
        }
        #expect(!sizes.isEmpty, "no built-in notation draws a junctor icon")
        #expect(sizes.filter { $0.value != 28 } == [:])
    }
}
