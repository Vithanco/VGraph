import Testing

@testable import VGraph

/// Every style a built-in notation gives a node type, keyed "Notation.NodeType".
/// Annotation and Warning come from an extension, and `Arithmetic.EqualsIncorrect`
/// is a state of the Equals node, not a node type; both are listed so that no
/// icon a built-in notation draws is missed.
enum BuiltInNodeTypeStyles {

    static func all() throws -> [(key: String, style: NodeStyleLayout)] {
        var styles: [(key: String, style: NodeStyleLayout)] = []
        for (name, entry) in NotationRegistry.entries {
            let graph = try VGraph().defineStandardAttributes().placing(entry.content, in: .builtin)
            for nodeType in graph.nodeTypes {
                if let style: NodeStyleLayout = try? graph.get(nodeType: nodeType, attribute: Attributes.Node.style) {
                    styles.append((key: "\(name).\(nodeType.description)", style: style))
                }
            }
        }
        styles.append((key: "Annotation.Annotation", style: .annotationNode))
        styles.append((key: "Annotation.Warning", style: .warningNode))
        styles.append(
            (
                key: "Arithmetic.EqualsIncorrect",
                style: ArithmeticEvaluation.equalsStyle(for: .incorrect(computed: [2], expected: 3))
            ))
        return styles
    }

    static func wearsNodeTypeBadge(_ style: NodeStyleLayout) -> Bool {
        !style.walkAll { layout -> Bool? in
            if case .typeBadge = layout { return true }
            return nil
        }.isEmpty
    }
}
