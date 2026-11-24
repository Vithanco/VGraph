/// Names VGL used to spell differently, still read; export writes only the
/// current spelling, so a saved file comes back up to date. One table for the
/// document body and `vnotation` blocks, so neither reads a name the other refuses.
public enum OlderVGLSpellings {
    /// Where a name is read: the same word is a different thing in each.
    public enum Place {
        /// An item's attribute in a document, or a diagram attribute in a `vnotation`.
        case attribute(AttributeTarget)
        /// A key of a `vnotation`'s `node type:` (`.node`), `edge type:` (`.edge`)
        /// or `group type:` (`.group`).
        case typeDeclaration(AttributeTarget)
    }

    public static func current(_ name: String, in place: Place) -> String {
        switch (name.lowercased(), place) {
        // Graphviz names from early VGL.
        case ("rankdir", .attribute), ("layout", .attribute): return Attributes.Group.layoutDirection.name
        case ("labelloc", .attribute): return Attributes.Group.labelLocation.name
        case ("diagramlogic", .attribute): return Attributes.Group.diagramLogic.name
        // Stated rather than left to `find(attributeByName:)`, whose last resort, a
        // substring match, finds nothing for "color": it fits the background and the font.
        case ("color", .attribute(.node)), ("color", .typeDeclaration(.node)):
            return Attributes.Node.backgroundColor.name
        // The native renderer draws a group from its border and background, so a
        // group's `color` is its background.
        case ("color", .attribute(.group)): return Attributes.Group.backgroundColor.name
        case ("boundarychrome", .attribute(.group)): return Attributes.Group.frame.name
        case ("boundarydash", .typeDeclaration(.node)), ("boundarydash", .typeDeclaration(.group)): return GroupFrame.dashKey
        case ("boundarycolor", .typeDeclaration(.node)), ("boundarycolor", .typeDeclaration(.group)): return GroupFrame.colorKey
        case ("boundaryfill", .typeDeclaration(.node)), ("boundaryfill", .typeDeclaration(.group)): return GroupFrame.fillKey
        case ("boundaryradius", .typeDeclaration(.node)), ("boundaryradius", .typeDeclaration(.group)):
            return GroupFrame.radiusKey
        // Degree bounds were first named for what they count per (ADR-0011).
        case ("persourcemin", .typeDeclaration(.edge)): return Attributes.Edge.outDegreeMin.name
        case ("persourcemax", .typeDeclaration(.edge)): return Attributes.Edge.outDegreeMax.name
        case ("pertargetmin", .typeDeclaration(.edge)): return Attributes.Edge.inDegreeMin.name
        case ("pertargetmax", .typeDeclaration(.edge)): return Attributes.Edge.inDegreeMax.name
        case ("totaloutmin", .typeDeclaration(.node)): return Attributes.Node.totalOutDegreeMin.name
        case ("totaloutmax", .typeDeclaration(.node)): return Attributes.Node.totalOutDegreeMax.name
        case ("totalinmin", .typeDeclaration(.node)): return Attributes.Node.totalInDegreeMin.name
        case ("totalinmax", .typeDeclaration(.node)): return Attributes.Node.totalInDegreeMax.name
        default: return name
        }
    }
}
