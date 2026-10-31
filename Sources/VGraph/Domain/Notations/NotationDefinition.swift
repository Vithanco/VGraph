/// Which notation a graph is drawn in, and what it declares beyond the values
/// its layers hold. These accumulate as the notation installs, where layered
/// values override, so they are not attributes (ADR-0030). The graph carries
/// them because the renderer and the quality checks see only a graph (ADR-0022).
public struct NotationDefinition: VProtocol {
    /// The notation's VGL name. A graph built in code is IBIS.
    public private(set) var name = "IBIS"
    /// The built-in notation a `vnotation` extends, by its VGL name.
    public private(set) var extends: String?
    public private(set) var extensions: [String] = []
    /// Registration order, which is the order menus offer them in.
    public private(set) var groupTypes: [GroupType] = []
    public private(set) var icons = IconRegistry()
    /// Empty means the built-in notation's own are in force.
    public private(set) var declaredQualityChecks: [QualityCheckSpec] = []
    public private(set) var declaredTransforms: [String] = []
    /// The boundary keys a `vnotation` wrote on each type. The layers hold the
    /// values, but they keep colours lossily, so which keys were written cannot
    /// be read back from them.
    private(set) var declaredBoundaryKeys: [ItemKey: [String]] = [:]
    /// Every type that details another, paired with it and the layer that first
    /// declared the pair, so an export can tell a `vnotation`'s own additions
    /// from what it inherits.
    private(set) var detailings: [DeclaredDetailing] = []

    struct DeclaredDetailing: VProtocol {
        let nodeType: NodeType
        let detailType: NodeType
        let layer: AttributeLayer
    }

    public init() {}

    func detailTypes(of nodeType: NodeType) -> [NodeType] {
        detailings.filter { $0.nodeType == nodeType }.map { $0.detailType }
    }

    func detailTypes(of nodeType: NodeType, declaredIn layer: AttributeLayer) -> [NodeType] {
        detailings.filter { $0.nodeType == nodeType && $0.layer == layer }.map { $0.detailType }
    }

    /// Detailings add up across layers; a pair already declared stays where it was.
    func declaring(_ detailing: Detailing, in layer: AttributeLayer) -> NotationDefinition {
        var result = self
        for detailType in detailing.detailTypes
        where !result.detailTypes(of: detailing.nodeType).contains(detailType) {
            result.detailings.append(DeclaredDetailing(nodeType: detailing.nodeType, detailType: detailType, layer: layer))
        }
        return result
    }

    func named(_ name: String) -> NotationDefinition {
        var result = self
        result.name = name
        return result
    }

    func extending(_ name: String?) -> NotationDefinition {
        var result = self
        result.extends = name
        return result
    }

    func with(extensions: [String]) -> NotationDefinition {
        var result = self
        result.extensions = extensions
        return result
    }

    func registering(_ groupType: GroupType) -> NotationDefinition {
        var result = self
        result.groupTypes.append(groupType)
        return result
    }

    func declaring(qualityChecks: [QualityCheckSpec]) -> NotationDefinition {
        var result = self
        result.declaredQualityChecks = qualityChecks
        return result
    }

    func declaring(transforms: [String]) -> NotationDefinition {
        var result = self
        result.declaredTransforms = transforms
        return result
    }

    func declaring(boundaryKeys: [ItemKey: [String]]) -> NotationDefinition {
        var result = self
        result.declaredBoundaryKeys = boundaryKeys
        return result
    }

    func declaring(icon name: String, artwork: IconArtwork) -> NotationDefinition {
        var result = self
        result.icons = icons.adding(name: name, artwork: artwork)
        return result
    }
}
