import VGraph

public struct DotExporter: ForExportAGraph {
    /// Maps attribute ids to their Graphviz DOT attribute names.
    /// We align with Graphviz naming conventions where possible.
    private static let graphvizNames: [Attribute.Id: String] = [
        // Node attributes
        Attributes.Node.margin.id: "margin",
        Attributes.Node.tooltip.id: "tooltip",
        Attributes.Node.position.id: "pos",
        Attributes.Node.width.id: "width",
        Attributes.Node.height.id: "height",
        Attributes.Node.fixedsize.id: "fixedsize",
        Attributes.Node.fontname.id: "fontname",
        Attributes.Node.fontsize.id: "fontsize",
        Attributes.Node.wrappedText.id: "label",
        Attributes.Node.shape.id: "shape",
        // Edge attributes
        Attributes.Edge.label.id: "label",
        Attributes.Edge.color.id: "color",
        Attributes.Edge.arrowHead.id: "arrowhead",
        Attributes.Edge.arrowTail.id: "arrowtail",
        Attributes.Edge.headLabel.id: "headlabel",
        Attributes.Edge.tailLabel.id: "taillabel",
        Attributes.Edge.fontname.id: "fontname",
        Attributes.Edge.penwidth.id: "penwidth",
        Attributes.Edge.style.id: "style",
        Attributes.Edge.dir.id: "dir",
        Attributes.Edge.weight.id: "weight",
        Attributes.Edge.constraint.id: "constraint",
        Attributes.Edge.len.id: "len",
        Attributes.Edge.labelangle.id: "labelangle",
        Attributes.Edge.labeldistance.id: "labeldistance",
        // Group attributes
        Attributes.Group.label.id: "label",
        Attributes.Group.fontname.id: "fontname",
        Attributes.Group.fontsize.id: "fontsize",
        Attributes.Group.labelocation.id: "labelloc",
        Attributes.Group.splines.id: "splines",
        Attributes.Group.ratio.id: "ratio",
        Attributes.Group.fontcolor.id: "fontcolor",
        Attributes.Group.backgroundColor.id: "bgcolor",
        Attributes.Group.border.id: "border",
        Attributes.Group.layoutDirection.id: "rankdir",
        Attributes.Group.style.id: "style",
        Attributes.Group.labeljust.id: "labeljust",
        Attributes.Group.overlap.id: "overlap",
        Attributes.Group.sep.id: "sep",
    ]

    /// What Graphviz assumes when DOT says nothing, in VGraph's spelling, where
    /// VGraph's own default differs. DOT carries what VGraph resolves, not just
    /// what was set: a value equal to VGraph's default is not stored (ADR-0030),
    /// and Graphviz has defaults of its own.
    private static let graphvizAssumes: [Attribute.Id: String] = [
        Attributes.Node.fontname.id: "Times-Roman",
        Attributes.Node.fontsize.id: "14",
        Attributes.Node.shape.id: "ellipse",
        Attributes.Group.fontname.id: "Times-Roman",
    ]

    public init() {}

    /// The values set along the element's chain, then any other translated
    /// value whose resolution Graphviz would not assume. Display values are
    /// written only when set: "not computed" is not "computed as nothing".
    private func translated(
        _ explicit: [Attribute.Id: String], target: AttributeTarget, graph: VGraph,
        resolve: (AttributeDefinition) -> String?
    ) -> [(Attribute.Id, String)] {
        var result: [(Attribute.Id, String)] = []
        for (id, value) in explicit where Self.graphvizNames[id] != nil {
            guard graph.attributeDefinitions[id]?.target == target else { continue }
            result.append((id, value))
        }
        var extra: [(Attribute.Id, String)] = []
        for (id, _) in Self.graphvizNames where explicit[id] == nil {
            guard let definition = graph.attributeDefinitions[id], definition.target == target,
                definition.category != .computed,
                let value = resolve(definition), !value.isEmpty,
                !Self.same(value, Self.graphvizAssumes[id] ?? definition.defaultValue)
            else { continue }
            extra.append((id, value))
        }
        return result + extra.sorted { $0.0.description < $1.0.description }
    }

    private static func same(_ a: String, _ b: String) -> Bool {
        if let x = Double(a), let y = Double(b) { return x == y }
        return a.lowercased() == b.lowercased()
    }

    /// Pad a label string with an extra `\n` on the side facing the graph content,
    /// so Graphviz allocates an extra line of vertical space between the label and nodes.
    private func paddedLabel(_ label: String, labelloc: String) -> String {
        let escaped = escapeQuotesOnly(label)
        guard labelloc == "t" else {
            return "\\n\(escaped)"  // padding above → pushes nodes away
        }
        return "\(escaped)\\n"  // padding below → pushes nodes away
    }

    private func formatGroupAttributes(_ attributes: [(Attribute.Id, String)]) -> String {
        var result = ""

        for (attrId, value) in attributes {
            guard let graphvizName = Self.graphvizNames[attrId] else {
                continue
            }

            let escapedValue = escapeQuotesOnly(Self.graphvizSpelling(name: graphvizName, value: value))
            result += "\t\t\(graphvizName)=\"\(escapedValue)\";\n"
        }

        return result
    }

    private func formatNode(_ node: Node, in graph: VGraph) throws(VError) -> String {
        let attributes = try formatAttributes(graph: graph, node: node)
        guard attributes.isEmpty else {
            return "\t\(node.id) [\(attributes)];\n"
        }
        return "\t\(node.id);\n"
    }

    /// Emits `id="..."` so the layout engine can key returned layout data by
    /// the model's edge id, avoiding any reliance on edge iteration order.
    private func formatEdge(_ edge: Edge, in graph: VGraph) throws(VError) -> String {
        let attributes = try formatAttributes(graph: graph, edge: edge.id)
        let idAttr = "id=\"\(escapeQuotesOnly(edge.id.description))\""
        let combined = attributes.isEmpty ? idAttr : "\(idAttr), \(attributes)"
        return "\t\(edge.from.id) -> \(edge.to.id) [\(combined)];\n"
    }

    public func export(graph: VGraph) throws(VError) -> String {
        let graphName: String = try graph.get(graphAttribute: Attributes.Group.label)
        let nameClause = graphName.isEmpty ? "" : " \"\(escapeQuotesOnly(graphName))\""
        var dotFile = "digraph\(nameClause) {\n"

        let graphAttrs = try formatGraphAttributes(graph: graph)
        dotFile += graphAttrs

        // Emit label with padding newline for spacing between graph title and nodes.
        // Root graph default labelloc is "b" (bottom).
        if !graphName.isEmpty {
            let attrs = try graph.getGraphAttributes()
            let labelloc = attrs[Attributes.Group.labelocation.id] ?? "b"
            dotFile += "\tlabel=\"\(paddedLabel(graphName, labelloc: labelloc))\";\n"
        }

        if !graphAttrs.isEmpty {
            dotFile += "\n"
        }

        // Collect align groups early — we need to know if newrank=true is required
        let alignGroups = try collectAlignGroups(graph: graph)
        let hasAlignGroups = alignGroups.values.contains { $0.count >= 2 }
        if hasAlignGroups {
            dotFile += "\tnewrank=true;\n\n"
        }

        // Inject engine-specific attributes for non-dot layout engines (neato, fdp, etc.)
        // Only use defaults if not explicitly set by the notation
        let engine: String = (try? graph.get(graphAttribute: Attributes.Group.layoutEngine)) ?? "dot"
        if engine != "dot" {
            let overlap: String = (try? graph.get(graphAttribute: Attributes.Group.overlap)) ?? ""
            let sep: String = (try? graph.get(graphAttribute: Attributes.Group.sep)) ?? ""

            if !overlap.isEmpty {
                dotFile += "\toverlap=\"\(escapeQuotesOnly(overlap))\";\n"
            } else {
                dotFile += "\toverlap=\"false\";\n"
            }

            if !sep.isEmpty {
                dotFile += "\tsep=\"\(escapeQuotesOnly(sep))\";\n"
            } else {
                dotFile += "\tsep=\"+25\";\n"
            }

            dotFile += "\n"
        }

        let traverser = GraphStructureTraverser.forStringOutput(
            onEnterGroup: { [self] (group: Group, graph: VGraph, _: Int) throws(VError) -> String in
                var result = "\tsubgraph cluster_\(group.id) {\n"
                var explicit = try graph.getAttributes(group: group)
                // A detailed node's title is its node label; Graphviz needs it to reserve room.
                if graph.isDetailed(group), let label = graph.label(of: .group(group)) {
                    explicit[Attributes.Group.label.id] = label
                }
                let attributes = translated(explicit, target: .graph, graph: graph) {
                    try? graph.get(group: group, attribute: $0)
                }
                result += formatGroupAttributes(attributes)
                return result
            },
            onExitGroup: { (_: Group, _: VGraph, _: Int) throws(VError) -> String in
                "\t}\n"
            },
            onNode: { [self] (node: Node, graph: VGraph, _: Int) throws(VError) -> String in
                try formatNode(node, in: graph)
            },
            onEdge: { [self] (edge: Edge, graph: VGraph) throws(VError) -> String in
                try formatEdge(edge, in: graph)
            }
        )

        dotFile += try traverser.traverse(graph)

        // Emit {rank=same} blocks for nodes sharing an alignGroup value
        dotFile += emitAlignGroups(alignGroups)

        dotFile += "}\n"
        return dotFile
    }

    private func formatAttributes(graph: VGraph, node: Node) throws(VError) -> String {
        var attributes = translated(try graph.getAttributes(node: node), target: .node, graph: graph) {
            try? graph.get(node: node, attribute: $0)
        }
        // Graphviz is told each node's size (`fixedsize`), so the text cannot change
        // where the node goes. It would only be measured with Times metrics, and
        // warn ("size too small for label") when that guess exceeds the box we
        // computed, as it does for a junctor whose label is its id.
        if attributes.contains(where: { $0.0 == Attributes.Node.fixedsize.id && $0.1 == "true" }) {
            attributes = attributes.map { $0.0 == Attributes.Node.wrappedText.id ? ($0.0, "") : $0 }
        }
        let base = formatAttributeContainer(attributes, definitions: graph.attributeDefinitions)
        // Derived so it cannot drift from the fill it describes. Safe to compute
        // here because Graphviz uses `color` for the pen, never for placement.
        guard let fill = graph.effectiveNodeLayout(for: node)?.backgroundFill else { return base }
        let color = formatDotAttribute(name: "color", value: fill.hexString)
        return base.isEmpty ? color : base + ", " + color
    }

    private func formatGraphAttributes(graph: VGraph) throws(VError) -> String {
        var explicit = try graph.getGraphAttributes()
        // Remove label — it is emitted separately with padding in export()
        explicit.removeValue(forKey: Attributes.Group.label.id)
        let attributes = translated(explicit, target: .graph, graph: graph) { definition in
            definition.id == Attributes.Group.label.id ? nil : try? graph.get(graphAttribute: definition)
        }
        return formatAttributeContainer(attributes, definitions: graph.attributeDefinitions, isGraphLevel: true)
    }

    private func formatAttributes(graph: VGraph, edge: Edge.Id) throws(VError) -> String {
        let attributes = translated(try graph.getAttributes(edge: edge), target: .edge, graph: graph) {
            try? graph.get(edge: edge, attribute: $0)
        }
        return formatAttributeContainer(attributes, definitions: graph.attributeDefinitions)
    }

    /// Converts array string format "[item1, item2]" to newline-separated format "item1\nitem2"
    private func formatArrayValue(_ value: String) -> String {
        var trimmed = value.trimmed()
        guard trimmed.hasPrefix("[") && trimmed.hasSuffix("]") else {
            return value
        }

        trimmed.removeFirst()
        trimmed.removeLast()

        guard !trimmed.isEmpty else {
            return ""
        }

        let elements = trimmed.components(separatedBy: ",").map {
            String($0).trimmed()
        }
        return elements.joined(separator: "\\n")
    }

    /// Converts point values to inches for width/height attributes
    private func convertPointsToInches(_ value: String) -> String {
        guard let numericValue = Double(value) else {
            return value
        }
        let inchValue = numericValue / 72.0
        return inchValue.asString
    }

    private func processAttributeValue(_ value: String, definition: AttributeDefinition) -> String {
        var processed = value

        if definition.typeAsString == "[String]" {
            processed = formatArrayValue(processed)
        }

        // Special handling for LayoutDirection: convert descriptive names to Graphviz rankdir values
        if definition.typeAsString == "LayoutDirection" {
            if let layoutDirection = try? LayoutDirection.fromString(value) {
                processed = layoutDirection.graphvizValue
            }
        }

        // DOT format: only escape quotes, not backslashes
        // Backslashes are used for escape sequences like \n, \t
        return escapeQuotesOnly(processed)
    }

    /// DOT uses backslashes for escape sequences, so we don't escape them
    private func escapeQuotesOnly(_ value: String) -> String {
        var result = ""
        for char in value {
            if char == "\"" {
                result += "\\\""
            } else {
                result.append(char)
            }
        }
        return result
    }

    private func formatDotAttribute(name: String, value: String) -> String {
        let needsConversion = name == "width" || name == "height"
        let finalValue = needsConversion ? convertPointsToInches(value) : Self.graphvizSpelling(name: name, value: value)
        return "\(name)=\"\(finalValue)\""
    }

    /// Values VGraph knows that Graphviz does not, spelled as the nearest thing it does.
    ///
    /// - `DM Sans` has no Graphviz metrics, so it measured every edge label, group
    ///   label and title with Times (0.50 of the size) and warned each time.
    ///   Helvetica (0.55) is nearer DM Sans (0.54). Node text is unaffected, as
    ///   nodes are sized here; the SVG still names DM Sans.
    /// - `person` is a C4 shape Graphviz cannot draw. It is laid out as a box.
    private static func graphvizSpelling(name: String, value: String) -> String {
        switch (name, value) {
        case ("fontname", FontFamily.dmSans.rawValue): return FontFamily.helvetica.rawValue
        case ("shape", NodeShape.person.asString): return NodeShape.box.asString
        default: return value
        }
    }

    private func collectAlignGroups(graph: VGraph) throws(VError) -> [String: [Node]] {
        var groupedNodes: [String: [Node]] = [:]
        for node in graph.nodes {
            let alignGroup: String = try graph.get(node: node, attribute: Attributes.Node.alignGroup)
            guard !alignGroup.isEmpty else { continue }
            groupedNodes[alignGroup, default: []].append(node)
        }
        return groupedNodes
    }

    private func emitAlignGroups(_ groupedNodes: [String: [Node]]) -> String {
        var result = ""
        for (_, nodes) in groupedNodes.sorted(by: { $0.key < $1.key }) where nodes.count >= 2 {
            let nodeIds = nodes.map { "\($0.id)" }.joined(separator: "; ")
            result += "\t{ rank=same; \(nodeIds); }\n"
        }
        return result
    }

    /// Only includes attributes that have a Graphviz name in the translation table
    private func formatAttributeContainer(
        _ container: [(Attribute.Id, String)],
        definitions: AttributeDefContainer,
        isGraphLevel: Bool = false
    ) -> String {
        var dotAttributes: [String] = []

        for (attrId, value) in container {
            guard let graphvizName = Self.graphvizNames[attrId],
                let definition = definitions[attrId]
            else {
                continue
            }

            let processedValue = processAttributeValue(value, definition: definition)
            let attribute = formatDotAttribute(name: graphvizName, value: processedValue)
            dotAttributes.append(attribute)
        }

        // Graph-level attributes are formatted one per line with semicolons
        // Node/edge attributes are comma-separated on one line
        guard isGraphLevel else {
            return dotAttributes.joined(separator: ", ")
        }
        return dotAttributes.map { "\t\($0);\n" }.joined()
    }
}

extension LayoutDirection {
    /// Converts the descriptive name to Graphviz's `rankdir` value.
    public var graphvizValue: String {
        switch self {
        case .topToBottom: return "TB"
        case .leftToRight: return "LR"
        case .bottomToTop: return "BT"
        case .rightToLeft: return "RL"
        }
    }
}
