/// Maps old VGL attribute names to canonical names for backward compatibility
/// in `vnotation` blocks. Mirrors the resolver in `VGLanguage.VGraphParser`.
private func resolveLegacyVnotationAttributeName(_ name: String) -> String {
    switch name.lowercased() {
    case "rankdir", "layout": return Attributes.Group.layoutDirection.name
    case "labelloc": return Attributes.Group.labelocation.name
    case "diagramlogic": return Attributes.Group.diagramLogic.name
    default: return name
    }
}

/// `nodeStyle` is required for new types but optional for overrides of inherited types.
public struct NodeTypeSpec {
    public let name: String
    /// `nil` when the user omitted `nodeStyle:` (valid only for overrides).
    public let nodeStyle: String?
    public let rawAttrs: [String: String]  // color, icon, iconColor, iconSize, fontsize, category, …
    /// Added to whatever the base notation already details this type by.
    public let detailedBy: [String]

    public init(name: String, nodeStyle: String?, rawAttrs: [String: String], detailedBy: [String] = []) {
        self.name = name
        self.nodeStyle = nodeStyle
        self.rawAttrs = rawAttrs
        self.detailedBy = detailedBy
    }
}

public struct EdgeTypeSpec {
    public let id: String
    public let from: String  // node type name
    public let to: String  // node type name
    public let rawAttrs: [String: String]

    public init(id: String, from: String, to: String, rawAttrs: [String: String]) {
        self.id = id
        self.from = from
        self.to = to
        self.rawAttrs = rawAttrs
    }
}

public struct DynamicNotation {
    public let id: Identifier<Notation>
    public let nodeTypeSpecs: [NodeTypeSpec]
    public let edgeTypeSpecs: [EdgeTypeSpec]
    public let groupTypes: [GroupType]
    public let groupTypeAttrs: [GroupType: [String: String]]
    public let graphAttrs: [(key: String, value: String)]
    /// Pre-resolved base notation entry from the `extends` clause; nil when not extending.
    /// Stored as a concrete `NotationEntry` value (not `any NotationProvider`) to keep
    /// the runtime dispatch path free of existentials.
    public let baseEntry: NotationEntry?
    /// The VGL-facing name of the base notation (e.g. "IBIS"), as typed in the
    /// `extends` clause. Distinct from `baseEntry.id` (which carries the Swift-internal
    /// id like "Ibis") — preserves the user-typed name for round-trip export.
    public let baseVglName: String?
    /// Installed onto the graph, because the renderer is handed a graph and never
    /// a notation (ADR-0022).
    public let icons: [(name: String, artwork: IconArtwork)]
    /// When non-empty and `extends` is used, these **replace** the base notation's compiled checks.
    public let qualityCheckSpecs: [QualityCheckSpec]
    /// Multiple transforms are composed left-to-right.
    /// When non-empty and `extends` is used, these **replace** the base notation's compiled transform.
    public let transformNames: [String]

    public init(
        id: Identifier<Notation>,
        nodeTypeSpecs: [NodeTypeSpec],
        edgeTypeSpecs: [EdgeTypeSpec],
        groupTypes: [GroupType] = [],
        groupTypeAttrs: [GroupType: [String: String]] = [:],
        graphAttrs: [(key: String, value: String)],
        baseEntry: NotationEntry?,
        baseVglName: String? = nil,
        icons: [(name: String, artwork: IconArtwork)] = [],
        qualityCheckSpecs: [QualityCheckSpec] = [],
        transformNames: [String] = []
    ) {
        self.id = id
        self.nodeTypeSpecs = nodeTypeSpecs
        self.edgeTypeSpecs = edgeTypeSpecs
        self.groupTypes = groupTypes
        self.groupTypeAttrs = groupTypeAttrs
        self.graphAttrs = graphAttrs
        self.baseEntry = baseEntry
        self.baseVglName = baseVglName
        self.icons = icons
        self.qualityCheckSpecs = qualityCheckSpecs
        self.transformNames = transformNames
    }

    /// The base notation goes into the built-in layer, the block into the
    /// document's `vnotation` layer (ADR-0030).
    public func addNotation(addTo graph: VGraph) throws(VError) -> VGraph {
        var result = graph
        let base = baseEntry?.content
        if let base {
            result = try result.placing(base, in: .builtin)
        }
        for icon in icons {
            result = try result.add(icon: icon.name, artwork: icon.artwork)
        }
        result = try result.placing(try content(over: base, vocabulary: result), in: .vnotation)
        if !qualityCheckSpecs.isEmpty {
            result = result.declaring(qualityChecks: qualityCheckSpecs)
        }
        if !transformNames.isEmpty {
            result = result.declaring(transforms: transformNames)
        }
        let boundaryKeys = declaredBoundaryKeys()
        if !boundaryKeys.isEmpty {
            result = result.declaring(boundaryKeys: boundaryKeys)
        }
        return result
    }

    private func declaredBoundaryKeys() -> [ItemKey: [String]] {
        let nodeTypes = nodeTypeSpecs.map { spec in
            (key: ItemKey(.nodeType, NodeType(string: spec.name).description), keys: BoundaryChrome.declaredKeys(in: spec.rawAttrs))
        }
        let groupTypes = groupTypeAttrs.map { entry in
            (key: ItemKey(.groupType, entry.key.description), keys: BoundaryChrome.declaredKeys(in: entry.value))
        }
        return Dictionary(
            (nodeTypes + groupTypes).filter { !$0.keys.isEmpty }.map { ($0.key, $0.keys) },
            uniquingKeysWith: { _, last in last })
    }

    /// What the block says. A type the base already has is overridden rather
    /// than added. `vocabulary` only names the diagram attributes a block may set.
    func content(over base: NotationContent?, vocabulary: VGraph) throws(VError) -> NotationContent {
        var content = NotationContent()

        for spec in nodeTypeSpecs {
            let nodeType = NodeType(string: spec.name)
            let isOverride = base != nil && ((base?.nodeTypes ?? []) + content.nodeTypes).contains(nodeType)
            if isOverride {
                let current =
                    content.value(of: Attributes.Node.nodeStyle.id, for: ItemKey(.nodeType, nodeType.description))
                    ?? base?.value(of: Attributes.Node.nodeStyle.id, for: ItemKey(.nodeType, nodeType.description))
                let boundary = currentBoundary(at: ItemKey(.nodeType, nodeType.description), in: content, over: base)
                content.values.append(
                    .nodeType(nodeType, try overrideValues(spec, nodeType, currentStyle: current, currentBoundary: boundary)))
            } else {
                content.nodeTypes.append(nodeType)
                content.values.append(.nodeType(nodeType, try newTypeValues(spec, nodeType)))
            }
            if !spec.detailedBy.isEmpty {
                content.detailings.append(
                    Detailing(nodeType: nodeType, detailTypes: spec.detailedBy.map { NodeType(string: $0) }))
            }
        }

        for spec in edgeTypeSpecs {
            let edgeType = EdgeType(id: spec.id, from: NodeType(string: spec.from), to: NodeType(string: spec.to))
            let isOverride = base != nil && ((base?.edgeTypes ?? []) + content.edgeTypes).contains { $0.id == edgeType.id }
            if !isOverride {
                content.edgeTypes.append(edgeType)
            }
            if !spec.rawAttrs.isEmpty {
                content.values.append(.edgeType(edgeType.id, try edgeValues(spec)))
            }
        }

        for groupType in groupTypes {
            if !((base?.groupTypes ?? []) + content.groupTypes).contains(groupType) {
                content.groupTypes.append(groupType)
            }
            let key = ItemKey(.groupType, groupType.description)
            let attrs = groupTypeAttrs[groupType] ?? [:]
            if let unknown = attrs.keys.sorted().first(where: { !BoundaryChrome.vnotationKeys.contains($0) }) {
                throw VError.parsingError("Unknown attribute '\(unknown)' on group type '\(groupType.description)'")
            }
            if let boundary = try BoundaryChrome.declared(in: attrs, over: currentBoundary(at: key, in: content, over: base)) {
                content.values.append(.groupType(groupType, [Attributes.Group.boundaryChrome(boundary)]))
            }
        }

        content.values.append(.diagram(try diagramValues(vocabulary)))
        return content
    }

    // MARK: - Private helpers

    /// What a type's boundary already is, so a block naming one key keeps the rest.
    private func currentBoundary(at key: ItemKey, in content: NotationContent, over base: NotationContent?)
        -> BoundaryChrome
    {
        func raw(_ id: Attribute.Id) -> String? { content.value(of: id, for: key) ?? base?.value(of: id, for: key) }
        return BoundaryChrome.inherited(
            boundary: raw(Attributes.Group.boundaryChrome.id).flatMap { try? BoundaryChrome.fromString($0) },
            style: raw(Attributes.Group.groupStyle.id).flatMap { try? GroupStyle.fromString($0) })
            ?? .default
    }

    private func diagramValues(_ vocabulary: VGraph) throws(VError) -> [Attribute] {
        var result: [Attribute] = []
        for (key, value) in graphAttrs {
            let resolvedKey = resolveLegacyVnotationAttributeName(key)
            guard let def = vocabulary.find(attributeByName: resolvedKey, for: .graph) else {
                throw VError.parsingError("Unknown graph attribute '\(key)' in vnotation '\(id)'")
            }
            // Use typed definitions for enum attributes to normalize stored values
            // (e.g., "topToBottom" → "Top to Bottom" for consistent round-trips)
            if def.id == Attributes.Group.layoutDirection.id {
                result.append(Attributes.Group.layoutDirection(try LayoutDirection.fromString(value)))
            } else if def.id == Attributes.Group.diagramLogic.id {
                result.append(Attributes.Group.diagramLogic(try DiagramLogic.fromString(value)))
            } else {
                result.append(try def.attribute(fromString: value))
            }
        }
        if baseEntry == nil && !graphAttrs.contains(where: { $0.key.lowercased() == "diagramlogic" }) {
            result.append(Attributes.Group.diagramLogic(.noLogic))
        }
        return result
    }

    /// `nodeStyle` is required — throws if missing.
    private func newTypeValues(_ spec: NodeTypeSpec, _ nodeType: NodeType) throws(VError) -> [Attribute] {
        guard let nodeStyleStr = spec.nodeStyle else {
            throw VError.parsingError("node type '\(spec.name)' is missing required attribute 'nodeStyle'")
        }
        let ns = try NodeStyle.fromString(nodeStyleStr)
        var result = [
            Attributes.Node.nodeStyle(ns),
            Attributes.Node.backgroundColor(StyleFactories.color(from: spec.rawAttrs).resolve(darkMode: false)),
        ]
        if ns.needsIcon {
            let defaultIconColorHex = (ns == .iconOnly) ? "#000000" : "#ffffff"
            result.append(Attributes.Node.iconInfo(StyleFactories.makeIcon(from: spec.rawAttrs, defaultIconColorHex: defaultIconColorHex)))
        }
        if ns.needsCategory {
            result.append(Attributes.Node.category(spec.rawAttrs["category"] ?? spec.name))
        }
        if let fontsizeStr = spec.rawAttrs["fontsize"], let fontsize = Double(fontsizeStr) {
            result.append(Attributes.Node.fontsize(fontsize))
        }
        if let boundary = try BoundaryChrome.declared(in: spec.rawAttrs, over: .default) {
            result.append(Attributes.Group.boundaryChrome(boundary))
        }
        return result + (try boundValues(spec.rawAttrs, nodeType))
    }

    /// `currentStyle` is what the type's `nodeStyle` resolves to before this
    /// override, if anything sets it; it picks the icon's default colour.
    private func overrideValues(
        _ spec: NodeTypeSpec, _ nodeType: NodeType, currentStyle: String?, currentBoundary: BoundaryChrome
    ) throws(VError) -> [Attribute] {
        var result: [Attribute] = []
        var style =
            try currentStyle.map { (s: String) throws(VError) in try NodeStyle.fromString(s) }
            ?? Attributes.Node.nodeStyle.defaultValue
        if let nodeStyleStr = spec.nodeStyle {
            style = try NodeStyle.fromString(nodeStyleStr)
            result.append(Attributes.Node.nodeStyle(style))
        }
        if StyleFactories.value(of: "backgroundColor", in: spec.rawAttrs) != nil
            || StyleFactories.value(of: "color", in: spec.rawAttrs) != nil
        {
            result.append(Attributes.Node.backgroundColor(StyleFactories.color(from: spec.rawAttrs).resolve(darkMode: false)))
        }
        if spec.rawAttrs["icon"] != nil {
            let defaultIconColorHex = (style == .iconOnly) ? "#000000" : "#ffffff"
            result.append(Attributes.Node.iconInfo(StyleFactories.makeIcon(from: spec.rawAttrs, defaultIconColorHex: defaultIconColorHex)))
        }
        if let cat = spec.rawAttrs["category"] {
            result.append(Attributes.Node.category(cat))
        }
        if let fontsizeStr = spec.rawAttrs["fontsize"], let fontsize = Double(fontsizeStr) {
            result.append(Attributes.Node.fontsize(fontsize))
        }
        if let boundary = try BoundaryChrome.declared(in: spec.rawAttrs, over: currentBoundary) {
            result.append(Attributes.Group.boundaryChrome(boundary))
        }
        return result + (try boundValues(spec.rawAttrs, nodeType))
    }

    private func edgeValues(_ spec: EdgeTypeSpec) throws(VError) -> [Attribute] {
        try ensureEachBoundOnce(spec.rawAttrs, spec.id) { Bound.edgeBound(named: $0) }
        var result: [Attribute] = []
        for (key, value) in spec.rawAttrs {
            switch key {
            case "arrowHead": result.append(Attributes.Edge.arrowHead(value))
            case "arrowTail": result.append(Attributes.Edge.arrowTail(value))
            case "style": result.append(Attributes.Edge.style(try Attributes.Edge.StyleType.fromString(value)))
            case "color": result.append(Attributes.Edge.color(try VColor.fromString(value)))
            case "penwidth":
                guard let pw = Double(value) else {
                    throw VError.parsingError("Invalid penwidth value '\(value)' for edge type '\(spec.id)'")
                }
                result.append(Attributes.Edge.penwidth(pw))
            case "constraint": result.append(Attributes.Edge.constraint(value.lowercased() == "true"))
            case "dir": result.append(Attributes.Edge.dir(value))
            case "headLabel": result.append(Attributes.Edge.headLabel(value))
            case "tailLabel": result.append(Attributes.Edge.tailLabel(value))
            case "len": result.append(Attributes.Edge.len(value))
            case "labelangle": result.append(Attributes.Edge.labelangle(value))
            case "labeldistance": result.append(Attributes.Edge.labeldistance(value))
            default:
                // Bounds come from one shared table (ADR-0011), so the
                // parser and the exporter cannot drift apart on their spellings.
                if let bound = Bound.edgeBound(named: key) {
                    result.append(try bound.definition.attribute(try boundValue(value, key, spec.id)))
                }
            // Anything else is still ignored, as it always has been.
            }
        }
        return result
    }

    private func boundValues(_ rawAttrs: [String: String], _ nodeType: NodeType) throws(VError) -> [Attribute] {
        try ensureEachBoundOnce(rawAttrs, nodeType.id) { Bound.nodeBound(named: $0) }
        var result: [Attribute] = []
        for (key, value) in rawAttrs {
            guard let bound = Bound.nodeBound(named: key) else { continue }
            result.append(try bound.definition.attribute(try boundValue(value, key, nodeType.id)))
        }
        return result
    }

    /// A bound under both its former and its new name contradicts itself, even with
    /// equal values (ADR-0011). Checked before applying: `rawAttrs` is a dictionary,
    /// so applying first would let whichever key came last win.
    private func ensureEachBoundOnce(
        _ rawAttrs: [String: String], _ owner: String, lookup: (String) -> Bound.Name?
    ) throws(VError) {
        var keysByBound: [String: [String]] = [:]
        for key in rawAttrs.keys {
            guard let bound = lookup(key) else { continue }
            keysByBound[bound.name, default: []].append(key)
        }
        for name in keysByBound.keys.sorted() {
            guard let keys = keysByBound[name], keys.count > 1 else { continue }
            throw VError.parsingError(
                "'\(owner)' gives \(name) twice, as \(keys.sorted().joined(separator: " and ")) — keep only \(name)")
        }
    }

    private func boundValue(_ value: String, _ key: String, _ owner: String) throws(VError) -> Int {
        guard let number = Int(value) else {
            throw VError.parsingError("Invalid \(key) value '\(value)' for '\(owner)' — expected a whole number")
        }
        return number
    }
}
