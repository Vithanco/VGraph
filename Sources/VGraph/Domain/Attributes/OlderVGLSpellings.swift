/// Names VGL used to spell differently, still read; export writes only the
/// current spelling, so a saved file comes back up to date. One table for the
/// document body and `vnotation` blocks, so neither reads a name the other refuses.
public enum OlderVGLSpellings {
    /// Where a name is read: the same word is a different thing in each.
    public enum Place {
        /// An item's attribute in a document, or a diagram attribute in a `vnotation`.
        case attribute(AttributeTarget)
        /// A key of a `vnotation`'s `node type:` or `group type:`.
        case typeDeclaration
    }

    public static func current(_ name: String, in place: Place) -> String {
        switch (name.lowercased(), place) {
        // Graphviz names from early VGL.
        case ("rankdir", .attribute), ("layout", .attribute): return Attributes.Group.layoutDirection.name
        case ("labelloc", .attribute): return Attributes.Group.labelLocation.name
        case ("diagramlogic", .attribute): return Attributes.Group.diagramLogic.name
        // Stated rather than left to `find(attributeByName:)`, whose last resort, a
        // substring match, finds nothing for "color": it fits the background and the font.
        case ("color", .attribute(.node)): return Attributes.Node.backgroundColor.name
        // The native renderer draws a group from its border and background, so a
        // group's `color` is its background.
        case ("color", .attribute(.group)): return Attributes.Group.backgroundColor.name
        case ("boundarychrome", .attribute(.group)): return Attributes.Group.frame.name
        case ("boundarydash", .typeDeclaration): return GroupFrame.dashKey
        case ("boundarycolor", .typeDeclaration): return GroupFrame.colorKey
        case ("boundaryfill", .typeDeclaration): return GroupFrame.fillKey
        case ("boundaryradius", .typeDeclaration): return GroupFrame.radiusKey
        default: return name
        }
    }

    /// A type declaration's keys in their current spelling. Where a block gives
    /// both spellings of one key, the current one wins.
    static func current(typeDeclaration attributes: [String: String]) -> [String: String] {
        Dictionary(
            attributes.compactMap { key, value -> (String, String)? in
                let name = current(key, in: .typeDeclaration)
                return name != key && attributes[name] != nil ? nil : (name, value)
            },
            uniquingKeysWith: { first, _ in first })
    }
}
