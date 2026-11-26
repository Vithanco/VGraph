/// `nodeStyle` is required for new types but optional for overrides of inherited types.
public struct NodeTypeSpec {
    public let name: String
    /// `nil` when the user omitted `nodeStyle:` (valid only for overrides).
    public let nodeStyle: String?
    public let rawAttributes: [String: String]  // backgroundColor, icon, iconColor, iconSize, fontsize, category, …
    /// Added to whatever the base notation already details this type by.
    public let detailedBy: [String]
    let keysGivenTwice: [KeyGivenTwice]

    public init(name: String, nodeStyle: String?, rawAttributes: [String: String], detailedBy: [String] = []) {
        self.name = name
        self.nodeStyle = nodeStyle
        (self.rawAttributes, self.keysGivenTwice) = VNotationKeys.reading(
            rawAttributes, of: .node, owner: ItemKey(NodeType(rawValue: name)))
        self.detailedBy = detailedBy
    }
}

public struct EdgeTypeSpec {
    public let id: String
    public let from: String  // node type name
    public let to: String  // node type name
    public let rawAttributes: [String: String]
    let keysGivenTwice: [KeyGivenTwice]

    public init(id: String, from: String, to: String, rawAttributes: [String: String]) {
        self.id = id
        self.from = from
        self.to = to
        (self.rawAttributes, self.keysGivenTwice) = VNotationKeys.reading(
            rawAttributes, of: .edge, owner: ItemKey(EdgeType.Id(rawValue: id)))
    }
}

public struct DynamicNotation {
    public let id: Identifier<Notation>
    public let nodeTypeSpecs: [NodeTypeSpec]
    public let edgeTypeSpecs: [EdgeTypeSpec]
    public let groupTypes: [GroupType]
    public let groupTypeAttributes: [GroupType: [String: String]]
    public let graphAttributes: [(key: String, value: String)]
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
    private let groupTypeKeysGivenTwice: [KeyGivenTwice]

    public init(
        id: Identifier<Notation>,
        nodeTypeSpecs: [NodeTypeSpec],
        edgeTypeSpecs: [EdgeTypeSpec],
        groupTypes: [GroupType] = [],
        groupTypeAttributes: [GroupType: [String: String]] = [:],
        graphAttributes: [(key: String, value: String)],
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
        let groupTypesRead = groupTypeAttributes.map { groupType, attributes in
            (groupType, VNotationKeys.reading(attributes, of: .group, owner: ItemKey(groupType)))
        }
        self.groupTypeAttributes = Dictionary(uniqueKeysWithValues: groupTypesRead.map { ($0.0, $0.1.attributes) })
        self.groupTypeKeysGivenTwice = groupTypesRead.sorted { $0.0.id < $1.0.id }.flatMap { $0.1.givenTwice }
        self.graphAttributes = graphAttributes
        self.baseEntry = baseEntry
        self.baseVglName = baseVglName
        self.icons = icons
        self.qualityCheckSpecs = qualityCheckSpecs
        self.transformNames = transformNames
    }

    /// The base notation goes into the built-in layer, the block into the
    /// document's `vnotation` layer (ADR-0030).
    public func addNotation(to graph: VGraph) throws(VError) -> VGraph {
        let base = baseEntry?.content
        let withBase = try base.map { (content) throws(VError) in try graph.placing(content, in: .builtin) } ?? graph
        let withIcons = icons.reduce(withBase) { result, icon in result.adding(icon: icon.name, artwork: icon.artwork) }
        let withBlock = try withIcons.placing(try content(over: base, vocabulary: withIcons), in: .vnotation)
        // Empty lists leave the built-in notation's own in force.
        let withChecks = qualityCheckSpecs.isEmpty ? withBlock : withBlock.declaring(qualityChecks: qualityCheckSpecs)
        let withTransforms = transformNames.isEmpty ? withChecks : withChecks.declaring(transforms: transformNames)
        let frameKeys = declaredFrameKeys()
        let withFrameKeys = frameKeys.isEmpty ? withTransforms : withTransforms.declaring(frameKeys: frameKeys)
        let withHeader = withFrameKeys.noting(headerReading(withIcons).givenTwice)
        let givenTwice =
            nodeTypeSpecs.flatMap { $0.keysGivenTwice } + edgeTypeSpecs.flatMap { $0.keysGivenTwice }
            + groupTypeKeysGivenTwice
        return givenTwice.isEmpty ? withHeader : withHeader.declaring(keysGivenTwice: givenTwice)
    }

    private func declaredFrameKeys() -> [ItemKey: [String]] {
        let nodeTypes = nodeTypeSpecs.map { spec in
            (key: ItemKey(NodeType(rawValue: spec.name)), keys: GroupFrame.declaredKeys(in: spec.rawAttributes))
        }
        let groupTypes = groupTypeAttributes.map { entry in
            (key: ItemKey(entry.key), keys: GroupFrame.declaredKeys(in: entry.value))
        }
        return Dictionary(
            (nodeTypes + groupTypes).filter { !$0.keys.isEmpty }.map { ($0.key, $0.keys) },
            uniquingKeysWith: { _, last in last })
    }

    /// What the block says. A type the base already has is overridden rather
    /// than added. `vocabulary` only names the diagram attributes a block may set.
    func content(over base: NotationContent?, vocabulary: VGraph) throws(VError) -> NotationContent {
        let withNodeTypes = try nodeTypeSpecs.folding(NotationContent()) { (content, spec) throws(VError) in
            try declaring(spec, in: content)
        }
        let withEdgeTypes = try edgeTypeSpecs.folding(withNodeTypes) { (content, spec) throws(VError) in
            try declaring(spec, in: content)
        }
        let withGroupTypes = try groupTypes.folding(withEdgeTypes) { (content, groupType) throws(VError) in
            try declaring(groupType, in: content)
        }
        return withGroupTypes.appending(.diagram(try diagramValues(vocabulary)))

        func declaring(_ spec: NodeTypeSpec, in content: NotationContent) throws(VError)
            -> NotationContent
        {
            let nodeType = NodeType(rawValue: spec.name)
            let key = ItemKey(nodeType)
            let isOverride = base != nil && ((base?.nodeTypes ?? []) + content.nodeTypes).contains(nodeType)
            let declared: NotationContent
            if isOverride {
                let currentStyle =
                    content.value(of: Attributes.Node.nodeStyle.id, for: key)
                    ?? base?.value(of: Attributes.Node.nodeStyle.id, for: key)
                let values = try overrideValues(
                    spec, nodeType, currentStyle: currentStyle, currentFrame: currentFrame(at: key, in: content, over: base))
                declared = content.appending(.nodeType(nodeType, values))
            } else {
                declared = content.adding(nodeType: nodeType).appending(.nodeType(nodeType, try newTypeValues(spec, nodeType)))
            }
            guard !spec.detailedBy.isEmpty else { return declared }
            return declared.adding(Detailing(nodeType: nodeType, detailTypes: spec.detailedBy.map { NodeType(rawValue: $0) }))
        }

        func declaring(_ spec: EdgeTypeSpec, in content: NotationContent) throws(VError)
            -> NotationContent
        {
            let edgeType = EdgeType(id: spec.id, from: NodeType(rawValue: spec.from), to: NodeType(rawValue: spec.to))
            let isOverride = base != nil && ((base?.edgeTypes ?? []) + content.edgeTypes).contains { $0.id == edgeType.id }
            let declared = isOverride ? content : content.adding(edgeType: edgeType)
            guard !spec.rawAttributes.isEmpty else { return declared }
            return declared.appending(.edgeType(edgeType.id, try edgeValues(spec)))
        }

        func declaring(_ groupType: GroupType, in content: NotationContent) throws(VError)
            -> NotationContent
        {
            let isNew = !((base?.groupTypes ?? []) + content.groupTypes).contains(groupType)
            let declared = isNew ? content.adding(groupType: groupType) : content
            let attributes = groupTypeAttributes[groupType] ?? [:]
            if let unknown = attributes.keys.sorted().first(where: { !GroupFrame.vnotationKeys.contains($0) }) {
                throw VError.parsingError("Unknown attribute '\(unknown)' on group type '\(groupType.description)'")
            }
            let key = ItemKey(groupType)
            guard let frame = try GroupFrame.declared(in: attributes, over: currentFrame(at: key, in: content, over: base))
            else { return declared }
            return declared.appending(.groupType(groupType, [Attributes.Group.frame(frame)]))
        }
    }

    // MARK: - Private helpers

    /// What a type's frame already is, so a block naming one key keeps the rest.
    private func currentFrame(at key: ItemKey, in content: NotationContent, over base: NotationContent?)
        -> GroupFrame
    {
        func raw(_ id: Attribute.Id) -> String? { content.value(of: id, for: key) ?? base?.value(of: id, for: key) }
        return GroupFrame.inherited(
            own: raw(Attributes.Group.frame.id).flatMap { try? GroupFrame.fromString($0) },
            style: raw(Attributes.Group.groupStyle.id).flatMap { try? GroupStyle.fromString($0) })
            ?? .default
    }

    private func diagramAttribute(named key: String, in vocabulary: VGraph) -> AttributeDefinition? {
        vocabulary.find(attributeByName: OlderVGLSpellings.current(key, in: .attribute(.group)), for: .group)
    }

    private func headerReading(_ vocabulary: VGraph) -> (overruled: Set<Int>, givenTwice: [AttributeGivenTwice]) {
        AttributeGivenTwice.reading(
            graphAttributes.map { key, value in
                WrittenAttribute(
                    owner: .root, spelling: key, value: value, definition: diagramAttribute(named: key, in: vocabulary))
            }, in: .vnotation)
    }

    private func diagramValues(_ vocabulary: VGraph) throws(VError) -> [Attribute] {
        let overruled = headerReading(vocabulary).overruled
        let applied = graphAttributes.enumerated().filter { !overruled.contains($0.offset) }.map { $0.element }
        let declared = try applied.map { (key, value) throws(VError) -> Attribute in
            guard let definition = diagramAttribute(named: key, in: vocabulary) else {
                throw VError.parsingError("Unknown graph attribute '\(key)' in vnotation '\(id)'")
            }
            // Enum values go through their type, so a stored value reads back the
            // same however the author spelled it.
            if definition.id == Attributes.Group.layoutDirection.id {
                return Attributes.Group.layoutDirection(try LayoutDirection.fromString(value))
            }
            if definition.id == Attributes.Group.diagramLogic.id {
                return Attributes.Group.diagramLogic(try DiagramLogic.fromString(value))
            }
            return definition.attribute(fromString: value)
        }
        let namesLogic = graphAttributes.contains { $0.key.lowercased() == "diagramlogic" }
        return baseEntry == nil && !namesLogic ? declared + [Attributes.Group.diagramLogic(.noLogic)] : declared
    }

    /// `nodeStyle` is required — throws if missing.
    private func newTypeValues(_ spec: NodeTypeSpec, _ nodeType: NodeType) throws(VError) -> [Attribute] {
        guard let styleName = spec.nodeStyle else {
            throw VError.parsingError("node type '\(spec.name)' is missing required attribute 'nodeStyle'")
        }
        let style = try NodeStyle.fromString(styleName)
        var result = [
            Attributes.Node.nodeStyle(style),
            Attributes.Node.backgroundColor(VNotationTypeAttributes.color(from: spec.rawAttributes).resolve(darkMode: false)),
        ]
        if style.needsIcon {
            result.append(
                Attributes.Node.iconInfo(
                    VNotationTypeAttributes.makeIcon(from: spec.rawAttributes, defaultIconColorHex: Self.defaultIconColorHex(for: style))))
        }
        if style.needsCategory {
            result.append(Attributes.Node.category(spec.rawAttributes["category"] ?? spec.name))
        }
        return result + (try sharedValues(spec, nodeType, frameOver: .default))
    }

    /// `currentStyle` is what the type's `nodeStyle` resolves to before this
    /// override, if anything sets it; it picks the icon's default colour.
    private func overrideValues(
        _ spec: NodeTypeSpec, _ nodeType: NodeType, currentStyle: String?, currentFrame: GroupFrame
    ) throws(VError) -> [Attribute] {
        var result: [Attribute] = []
        let declaredStyle = try spec.nodeStyle.map { (name) throws(VError) in try NodeStyle.fromString(name) }
        let inheritedStyle = try currentStyle.map { (name) throws(VError) in try NodeStyle.fromString(name) }
        let style = declaredStyle ?? inheritedStyle ?? Attributes.Node.nodeStyle.defaultValue
        if let declaredStyle {
            result.append(Attributes.Node.nodeStyle(declaredStyle))
        }
        if spec.rawAttributes[Attributes.Node.backgroundColor.name] != nil {
            result.append(Attributes.Node.backgroundColor(VNotationTypeAttributes.color(from: spec.rawAttributes).resolve(darkMode: false)))
        }
        if spec.rawAttributes["icon"] != nil {
            result.append(
                Attributes.Node.iconInfo(
                    VNotationTypeAttributes.makeIcon(from: spec.rawAttributes, defaultIconColorHex: Self.defaultIconColorHex(for: style))))
        }
        if let category = spec.rawAttributes["category"] {
            result.append(Attributes.Node.category(category))
        }
        return result + (try sharedValues(spec, nodeType, frameOver: currentFrame))
    }

    /// What a new type and an override read the same way: font size, frame, bounds, neighbourhood.
    private func sharedValues(_ spec: NodeTypeSpec, _ nodeType: NodeType, frameOver inherited: GroupFrame) throws(VError)
        -> [Attribute]
    {
        let fontsize = spec.rawAttributes["fontsize"].flatMap { Double($0) }.map { [Attributes.Node.fontsize($0)] } ?? []
        let frame = try GroupFrame.declared(in: spec.rawAttributes, over: inherited).map { [Attributes.Group.frame($0)] } ?? []
        return fontsize + frame + (try boundValues(spec.rawAttributes, nodeType)) + (try neighborhoodValues(spec.rawAttributes))
    }

    private static func defaultIconColorHex(for style: NodeStyle) -> String {
        style == .iconOnly ? "#000000" : "#ffffff"
    }

    private func edgeValues(_ spec: EdgeTypeSpec) throws(VError) -> [Attribute] {
        var result: [Attribute] = []
        for (key, value) in spec.rawAttributes {
            switch key {
            case "arrowHead": result.append(Attributes.Edge.arrowHead(value))
            case "arrowTail": result.append(Attributes.Edge.arrowTail(value))
            case "style": result.append(Attributes.Edge.style(try Attributes.Edge.StyleType.fromString(value)))
            case "color": result.append(Attributes.Edge.color(try VColor.fromString(value)))
            case "penwidth":
                guard let penwidth = Double(value) else {
                    throw VError.parsingError("Invalid penwidth value '\(value)' for edge type '\(spec.id)'")
                }
                result.append(Attributes.Edge.penwidth(penwidth))
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
                if let degreeLimit = Bound.edgeBound(named: key)?.definition {
                    result.append(degreeLimit(try boundValue(value, key, spec.id)))
                }
            // Anything else is still ignored, as it always has been.
            }
        }
        return result
    }

    private func neighborhoodValues(_ rawAttributes: [String: String]) throws(VError) -> [Attribute] {
        guard let raw = rawAttributes[Attributes.Node.addsToNeighborhood.name] else { return [] }
        return [Attributes.Node.addsToNeighborhood(try AddsToNeighborhood.fromString(raw))]
    }

    private func boundValues(_ rawAttributes: [String: String], _ nodeType: NodeType) throws(VError) -> [Attribute] {
        var result: [Attribute] = []
        for (key, value) in rawAttributes {
            guard let degreeLimit = Bound.nodeBound(named: key)?.definition else { continue }
            result.append(degreeLimit(try boundValue(value, key, nodeType.id)))
        }
        return result
    }

    private func boundValue(_ value: String, _ key: String, _ owner: String) throws(VError) -> Int {
        guard let number = Int(value) else {
            throw VError.parsingError("Invalid \(key) value '\(value)' for '\(owner)' — expected a whole number")
        }
        return number
    }
}
