import VGraph

public struct VGLExporter: ForExportAGraph {
    public init() {}

    // MARK: - Comment emission

    /// `AttributeContainer` is a dictionary; without a deliberate order a
    /// document reorders itself between one save and the next.
    private func sortedForOutput(_ attributes: [Attribute.Id: String], in graph: VGraph) -> [(key: Attribute.Id, value: String)] {
        attributes.sorted { graph.attributeDefinitions[$0.key]!.vglKey < graph.attributeDefinitions[$1.key]!.vglKey }
    }

    private func leadingComment(_ attributes: AttributeContainer, _ id: Attribute.Id, indentation: String) -> String {
        guard let stored = attributes[id], !stored.isEmpty else { return "" }
        var output = ""
        for line in CommentAttributes.canonical(stored).split(separator: "\n", omittingEmptySubsequences: false) {
            output += line.isEmpty ? "\n" : "\(indentation)\(line)\n"
        }
        return output
    }

    /// What a layer holds that belongs in the text: not the comments or the
    /// declaration's own slots, which are written elsewhere, and never what the
    /// Display pipeline computes.
    private func authored(
        _ values: AttributeContainer, in graph: VGraph, except excluded: Set<Attribute.Id>
    ) -> AttributeContainer {
        values.filter { id, _ in
            !excluded.contains(id) && graph.attributeDefinitions[id].map { $0.category != .computed } ?? false
        }
    }

    private func trailingComment(_ attributes: AttributeContainer, _ id: Attribute.Id) -> String {
        guard let stored = attributes[id], !stored.isEmpty else { return "" }
        return "  \(CommentAttributes.canonical(stored))"
    }

    public func export(graph: VGraph) throws(VError) -> String {
        try graph.requirePristineForDocumentExport()
        var output = ""

        let graphId: String = try graph.get(graphAttribute: Attributes.Group.Id)
        let graphLabel: String = try graph.get(graphAttribute: Attributes.Group.label)

        let notation = graph.notationName

        if !isBuiltinNotation(notation) {
            output += try reconstructVNotation(graph: graph, notationName: notation)
            output += "\n"
        }

        let typeDecl = ([notation] + graph.notationDefinition.extensions).joined(separator: ", ")

        let graphAttrs = try graph.getGraphAttributes()

        // The file's own comments sit above the declaration, below any vnotation block.
        output += leadingComment(graphAttrs, Attributes.Group.comment.id, indentation: "")

        output += "vgraph \(graphId): \(typeDecl) \"\(StringEscaping.escape(graphLabel))\" {"
        output += trailingComment(graphAttrs, Attributes.Group.trailingComment.id)
        output += "\n"

        // The model's own values; the id and label are in the declaration.
        let authoredGraphAttrs = authored(
            try graph.attributes(in: .model, of: .root), in: graph,
            except: CommentAttributes.group.union([Attributes.Group.Id.id, Attributes.Group.label.id]))

        for (key, value) in sortedForOutput(authoredGraphAttrs, in: graph) {
            let def = graph.attributeDefinitions[key]!
            let name = def.vglKey
            let quotedValue = needsQuoting(value) ? "\"\(StringEscaping.escape(value))\"" : value
            output += "\t\(name): \(quotedValue)\n"
        }

        if !authoredGraphAttrs.isEmpty {
            output += "\n"
        }

        // VGL exports nodes before groups (nodesFirst order)
        let traverser = GraphStructureTraverser.forStringOutput(
            onEnterGroup: { [self] (group: Group, graph: VGraph, depth: Int) throws(VError) -> String in
                try formatGroupEnter(group, in: graph, indent: depth + 1)
            },
            onExitGroup: { (_: Group, _: VGraph, depth: Int) throws(VError) -> String in
                let indentation = String(repeating: "\t", count: depth + 1)
                return "\(indentation)}\n"
            },
            onNode: { [self] (node: Node, graph: VGraph, depth: Int) throws(VError) -> String in
                try formatNode(node, in: graph, indent: depth + 1)
            },
            onEdge: { [self] (edge: Edge, graph: VGraph) throws(VError) -> String in
                try formatEdge(edge, in: graph, indent: 1)
            },
            order: .nodesFirst
        )

        output += try traverser.traverse(graph)
        output += "}\n"
        for view in graph.views {
            output += "\n"
            output += try formatView(view, in: graph)
        }
        return output
    }

    /// Walks the view's own keys, not the graph's elements, so a statement
    /// naming something the model lacks is written back like any other.
    private func formatView(_ view: ViewDeclaration, in graph: VGraph) throws(VError) -> String {
        var header = "vview \(view.name)"
        if let label = view.label { header += " \"\(StringEscaping.escape(label))\"" }
        let rootValues = authored(try graph.attributes(inView: view.name, of: .root), in: graph, except: [])
        if !rootValues.isEmpty { header += " \(bracketed(rootValues, in: graph))" }

        var output = header + " {\n"
        for rule in view.rules { output += "\t\(format(rule))\n" }
        for key in try graph.keys(inView: view.name) where key.kind != .root {
            var values = authored(try graph.attributes(inView: view.name, of: key), in: graph, except: [])
            var keyword: String
            switch key.kind {
            case .node: keyword = "node \(key.id)"
            case .nodeType: keyword = "node type: \(key.id)"
            case .group: keyword = "group \(key.id)"
            case .groupType: keyword = "group type: \(key.id)"
            case .root, .edge, .edgeType: continue
            }
            if values[Attributes.Group.isFolded.id] == "true", key.kind != .node {
                values[Attributes.Group.isFolded.id] = nil
                keyword = "folded " + keyword
            }
            output += "\t\(keyword)"
            if !values.isEmpty { output += " \(bracketed(values, in: graph))" }
            output += "\n"
        }
        return output + "}\n"
    }

    private func format(_ rule: ViewRule) -> String {
        switch rule {
        case .expand(let steps): return "expand \(steps)"
        case .include(let selector): return "include \(format(selector))"
        case .exclude(let selector): return "exclude \(format(selector))"
        }
    }

    private func format(_ selector: Selector) -> String {
        var text: String
        switch selector.subject {
        case .everything: text = "*"
        case .nodes(let names): text = "node " + names.joined(separator: ", ")
        case .groups(let names): text = "group " + names.joined(separator: ", ")
        case .nodeTypes(let names): text = "node type: " + names.joined(separator: ", ")
        case .groupTypes(let names): text = "group type: " + names.joined(separator: ", ")
        }
        switch selector.reach {
        case .downstream(let steps)?: text += " downstream \(steps)"
        case .upstream(let steps)?: text += " upstream \(steps)"
        case .around(let steps)?: text += " +\(steps)"
        case nil: break
        }
        return text
    }

    private func bracketed(_ values: AttributeContainer, in graph: VGraph) -> String {
        let pairs = sortedForOutput(values, in: graph).map { key, value in
            "\(graph.attributeDefinitions[key]!.vglKey): \(quoteIfNeeded(value))"
        }
        return "[\(pairs.joined(separator: ", "))]"
    }

    private func formatNode(_ node: Node, in graph: VGraph, indent: Int) throws(VError) -> String {
        let indentation = String(repeating: "\t", count: indent)
        var output = ""

        let nodeType = try graph.nodeType(for: node)
        // Only get label if explicitly set on this node (not inherited default)
        let ownAttributes = graph.getOwnAttributes(node: node)
        let label = ownAttributes[Attributes.Node.label.id]

        output += leadingComment(ownAttributes, Attributes.Node.comment.id, indentation: indentation)

        // Only include label if it exists and is non-empty. An unlabeled node
        // defaults its label to its id in the parser, so it is emitted here
        // explicitly (e.g. `node leads: Relation "leads"`) — which is fine.
        if let label = label, !label.isEmpty {
            output += "\(indentation)node \(node.id): \(nodeType.id) \"\(StringEscaping.escape(label))\""
        } else {
            output += "\(indentation)node \(node.id): \(nodeType.id)"
        }

        let nonDefaultAttrs = authored(
            ownAttributes, in: graph, except: CommentAttributes.node.union([Attributes.Node.label.id]))

        if !nonDefaultAttrs.isEmpty {
            output += " ["
            let attrStrings = sortedForOutput(nonDefaultAttrs, in: graph).map { key, value in
                let def = graph.attributeDefinitions[key]!
                let name = def.vglKey
                let quotedValue = needsQuoting(value) ? "\"\(StringEscaping.escape(value))\"" : value
                return "\(name): \(quotedValue)"
            }
            output += attrStrings.joined(separator: ", ")
            output += "]"
        }

        output += trailingComment(ownAttributes, Attributes.Node.trailingComment.id)
        output += "\n"
        return output
    }

    private func formatGroupEnter(_ group: Group, in graph: VGraph, indent: Int) throws(VError) -> String {
        let indentation = String(repeating: "\t", count: indent)
        var output = ""

        let groupId = group.id.description
        let label = graph.label(of: .group(group)) ?? ""
        let slots: (leading: Attribute.Id, trailing: Attribute.Id, label: Attribute.Id) =
            graph.isDetailed(group)
            ? (Attributes.Node.comment.id, Attributes.Node.trailingComment.id, Attributes.Node.label.id)
            : (Attributes.Group.comment.id, Attributes.Group.trailingComment.id, Attributes.Group.label.id)
        // The group's own values, not its type's: a type that starts folded is not
        // a `folded` group, and a `false` against it is written as `isfolded`.
        let attributes = try graph.getAttributes(group: group)
        let isFolded = attributes[Attributes.Group.isFolded.id] == "true"

        let groupType = graph.nodeType(of: group)?.description ?? graph.groupType(of: group)?.description ?? ""
        let typeSlot = groupType.isEmpty ? "" : ": \(groupType)"

        // The separating blank line comes first: the comments stay welded to the
        // declaration, so re-parsing finds the blank outside the run.
        output += "\n"
        output += leadingComment(attributes, slots.leading, indentation: indentation)

        let keyword = isFolded ? "folded group" : "group"
        output += "\(indentation)\(keyword) \(groupId)\(typeSlot) \"\(StringEscaping.escape(label))\" {"
        output += trailingComment(attributes, slots.trailing)
        output += "\n"

        var excluded: Set<Attribute.Id> = [slots.leading, slots.trailing, slots.label, Attributes.Group.Id.id]
        if isFolded { excluded.insert(Attributes.Group.isFolded.id) }
        let nonDefaultAttrs = authored(attributes, in: graph, except: excluded)

        for (key, value) in sortedForOutput(nonDefaultAttrs, in: graph) {
            let def = graph.attributeDefinitions[key]!
            let name = def.vglKey
            let quotedValue = needsQuoting(value) ? "\"\(StringEscaping.escape(value))\"" : value
            output += "\(indentation)\t\(name): \(quotedValue)\n"
        }

        return output
    }

    private func formatEdge(_ edge: Edge, in graph: VGraph, indent: Int) throws(VError) -> String {
        let indentation = String(repeating: "\t", count: indent)
        var output = ""

        let edgeType = try graph.edgeType(for: edge.id)
        let ownAttributes = graph.getOwnAttributes(edge: edge.id)

        output += leadingComment(ownAttributes, Attributes.Edge.comment.id, indentation: indentation)
        output += "\(indentation)edge \(edge.from.id) -> \(edge.to.id)"

        // Only include edge type if it's not inferrable (i.e., multiple edge types are possible)
        let possibleEdgeTypes = graph.edgeTypes(
            holdingFrom: try graph.nodeType(for: edge.from), to: try graph.nodeType(for: edge.to))
        if possibleEdgeTypes.count != 1 {
            output += ": \(edgeType.id)"
        }
        // If exactly 1 edge type is possible, omit it (parser will infer)

        let attributes = try graph.getAttributes(edge: edge.id)
        if let labelValue = attributes[Attributes.Edge.label.id] {
            output += " \"\(StringEscaping.escape(labelValue))\""
        }

        let nonDefaultAttrs = authored(
            ownAttributes, in: graph, except: CommentAttributes.edge.union([Attributes.Edge.label.id]))
        if !nonDefaultAttrs.isEmpty {
            output += " ["
            let attrStrings = sortedForOutput(nonDefaultAttrs, in: graph).map { key, value in
                let def = graph.attributeDefinitions[key]!
                let name = def.vglKey
                let quotedValue = needsQuoting(value) ? "\"\(StringEscaping.escape(value))\"" : value
                return "\(name): \(quotedValue)"
            }
            output += attrStrings.joined(separator: ", ")
            output += "]"
        }

        output += trailingComment(ownAttributes, Attributes.Edge.trailingComment.id)
        output += "\n"
        return output
    }

    // MARK: - VNotation reconstruction

    private func isBuiltinNotation(_ name: String) -> Bool {
        NotationRegistry.entries.contains { $0.id == name }
    }

    /// What the notation a `vnotation` extends says, read from the same graph's
    /// built-in layer rather than from a rebuilt copy of the notation.
    private struct Base {
        let entry: NotationEntry
        let graph: VGraph

        func has(nodeType: NodeType) -> Bool { entry.nodeTypeDefinitions.contains { $0.nodeType == nodeType } }
        func has(edgeType: EdgeType.Id) -> Bool { entry.edgeTypeDefinitions.contains { $0.edgeType.id == edgeType } }
        func has(groupType: GroupType) -> Bool { entry.groupTypeDefinitions.contains { $0.groupType == groupType } }

        func value<T: AttributeType>(_ definition: TypedAttributeDefinition<T>, of key: ItemKey) -> T? {
            graph.value(definition, of: key, through: .builtin)
        }
    }

    private func reconstructVNotation(graph: VGraph, notationName: String) throws(VError) -> String {
        let extendsName = graph.notationDefinition.extends ?? ""
        let base = NotationRegistry.entry(for: extendsName).map { Base(entry: $0, graph: graph) }

        var output = "vnotation \(notationName)"
        if !extendsName.isEmpty {
            output += " extends \(extendsName)"
        }
        output += " {\n"

        // Graph-level attributes: emit those that differ from base (or from default if no base)
        // The comments belong to the document, which emits them itself as `//`
        // lines; a graph attribute is only where they are stored.
        let vnotationExcludedAttrs: Set<Attribute.Id> = CommentAttributes.group.union([
            Attributes.Group.Id.id,
            Attributes.Group.label.id,
        ])
        let ownGraphAttrs = authored(
            try graph.attributes(in: .vnotation, of: .root), in: graph, except: vnotationExcludedAttrs)
        let graphLines = ownGraphAttrs.map { attrId, value in
            let def = graph.attributeDefinitions[attrId]!
            return (key: vnotationKeyName(for: def), value: quoteIfNeeded(vnotationValue(value, for: def)))
        }
        for line in graphLines.sorted(by: { $0.key < $1.key }) {
            output += "\t\(line.key): \(line.value)\n"
        }

        // Every declaration, not only the ones a node type names: dropping an
        // unused one would delete something the author wrote. Sorted because the
        // graph carries a table, which has no source order to preserve.
        let declaredIcons = graph.declaredIcons
        if !declaredIcons.isEmpty {
            output += "\n"
            for name in declaredIcons.keys.sorted() {
                let artwork = declaredIcons[name]!
                output += "\ticon \(name) [viewBox: \"\(artwork.viewBox)\", path: \"\(artwork.path)\"]\n"
            }
        }

        var hasNodeTypes = false
        for nodeType in graph.nodeTypes {
            if let line = try reconstructNodeTypeSpec(nodeType: nodeType, graph: graph, base: base) {
                if !hasNodeTypes {
                    output += "\n"
                    hasNodeTypes = true
                }
                output += "\t\(line)\n"
            }
        }

        var hasEdgeTypes = false
        for edgeType in graph.edgeTypes {
            if let line = try reconstructEdgeTypeSpec(edgeType: edgeType, graph: graph, base: base) {
                if !hasEdgeTypes {
                    output += "\n"
                    hasEdgeTypes = true
                }
                output += "\t\(line)\n"
            }
        }

        let groupTypeLines = graph.groupTypes.compactMap { type -> String? in
            guard !type.isUnknown else { return nil }
            let keys = ownBoundaryKeys(at: ItemKey(.groupType, type.description), in: graph)
            guard !(base?.has(groupType: type) ?? false) || !keys.isEmpty else { return nil }
            let attrsStr = keys.isEmpty ? "" : " [" + keys.map { "\($0.key): \($0.value)" }.joined(separator: ", ") + "]"
            return "group type: \(type.description)\(attrsStr)"
        }
        if !groupTypeLines.isEmpty {
            output += "\n"
            for line in groupTypeLines {
                output += "\t\(line)\n"
            }
        }

        let declaredChecks = graph.notationDefinition.declaredQualityChecks
        if !declaredChecks.isEmpty {
            output += "\n"
            for spec in declaredChecks {
                output += "\tqualityCheck: \(spec.specString)\n"
            }
        }

        let names = graph.notationDefinition.declaredTransforms
        if !names.isEmpty {
            if declaredChecks.isEmpty { output += "\n" }
            for name in names {
                output += "\ttransform: \(name)\n"
            }
        }

        output += "}\n"
        return output
    }

    private func ownBoundaryKeys(at key: ItemKey, in graph: VGraph) -> [(key: String, value: String)] {
        graph.declaredBoundary(of: key).map { (key: $0.key, value: quoteIfNeeded($0.value)) }
    }

    private func reconstructNodeTypeSpec(nodeType: NodeType, graph: VGraph, base: Base?) throws(VError) -> String? {
        let isInBase = base?.has(nodeType: nodeType) ?? false
        let key = ItemKey(.nodeType, nodeType.description)

        // For types not in the base, emit a full declaration.
        // For types in the base, emit only changed attributes (override mode).
        var attrs: [(key: String, value: String)] = []

        let nodeStyle: NodeStyle = try graph.get(nodeType: nodeType, attribute: Attributes.Node.nodeStyle)
        let bgColor: VColor = try graph.get(nodeType: nodeType, attribute: Attributes.Node.backgroundColor)
        let iconInfo: IconInfo? = try? graph.get(nodeType: nodeType, attribute: Attributes.Node.iconInfo)
        let category: String = (try? graph.get(nodeType: nodeType, attribute: Attributes.Node.category)) ?? ""
        let fontsize: Double = (try? graph.get(nodeType: nodeType, attribute: Attributes.Node.fontsize)) ?? Attributes.Node.fontsize.defaultValue

        if isInBase {
            let base = base!
            let baseNodeStyle = base.value(Attributes.Node.nodeStyle, of: key) ?? Attributes.Node.nodeStyle.defaultValue
            let baseBgColor = base.value(Attributes.Node.backgroundColor, of: key) ?? Attributes.Node.backgroundColor.defaultValue
            let baseIconInfo: IconInfo? = base.value(Attributes.Node.iconInfo, of: key)
            let baseCategory = base.value(Attributes.Node.category, of: key) ?? ""
            let baseFontsize = base.value(Attributes.Node.fontsize, of: key) ?? Attributes.Node.fontsize.defaultValue

            if nodeStyle != baseNodeStyle { attrs.append(("nodeStyle", nodeStyle.asString)) }
            if bgColor != baseBgColor { attrs.append(("backgroundColor", "\"\(bgColor.hexString)\"")) }
            if let iconInfo, let baseIconInfo {
                if iconInfo.iconName != baseIconInfo.iconName { attrs.append(("icon", "\"\(iconInfo.iconName)\"")) }
                if iconInfo.iconColor != baseIconInfo.iconColor { attrs.append(("iconColor", "\"\(iconInfo.iconColor.hexString)\"")) }
                if iconInfo.iconSize != baseIconInfo.iconSize { attrs.append(("iconSize", "\(Int(iconInfo.iconSize))")) }
            } else if let iconInfo, baseIconInfo == nil {
                attrs.append(("icon", "\"\(iconInfo.iconName)\""))
            }
            if category != baseCategory && !category.isEmpty { attrs.append(("category", "\"\(category)\"")) }
            if fontsize != baseFontsize { attrs.append(("fontsize", "\(Int(fontsize))")) }

            // Deliberately no early return here — see the isEmpty check below the
            // bound append.
        } else {
            attrs.append(("nodeStyle", nodeStyle.asString))
            attrs.append(("backgroundColor", "\"\(bgColor.hexString)\""))
            if let iconInfo, nodeStyle.needsIcon && !iconInfo.iconName.isEmpty {
                attrs.append(("icon", "\"\(iconInfo.iconName)\""))
                let defaultIconColorHex = (nodeStyle == .iconOnly) ? "#000000" : "#ffffff"
                if iconInfo.iconColor.hexString != defaultIconColorHex {
                    attrs.append(("iconColor", "\"\(iconInfo.iconColor.hexString)\""))
                }
            }
            if nodeStyle.needsCategory && !category.isEmpty {
                attrs.append(("category", "\"\(category)\""))
            }
            if fontsize != Attributes.Node.fontsize.defaultValue {
                attrs.append(("fontsize", "\(Int(fontsize))"))
            }
        }

        attrs.append(
            contentsOf: boundAttrs(
                Bound.nodeBounds,
                read: { definition in try? graph.get(nodeType: nodeType, attribute: definition) },
                base: base.map { base in { definition in base.value(definition, of: key) } }))

        let ownDetailTypes = graph.detailTypes(of: nodeType, declaredIn: .vnotation)
        if !ownDetailTypes.isEmpty {
            attrs.append(("detailedBy", "(\(ownDetailTypes.map { $0.id }.joined(separator: ", ")))"))
        }
        attrs.append(contentsOf: ownBoundaryKeys(at: key, in: graph))

        // Must stay below the appends: a bound can be the only difference from the
        // base, and deciding "nothing changed" first would drop the declaration.
        if isInBase && attrs.isEmpty { return nil }

        let attrsStr = attrs.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
        return "node type: \(nodeType.id) [\(attrsStr)]"
    }

    /// Emit every bound that differs from the base notation (or from its default
    /// when there is no base). Driven by `Bound`'s own table so the exporter
    /// and `applyEdgeTypeAttributes` cannot disagree about the spellings.
    private func boundAttrs(
        _ bounds: [Bound.Name],
        read: (TypedAttributeDefinition<Int>) -> Int?,
        base: ((TypedAttributeDefinition<Int>) -> Int?)?
    ) -> [(key: String, value: String)] {
        var result: [(key: String, value: String)] = []
        for bound in bounds {
            let value = read(bound.definition) ?? Bound.unbounded
            let reference = base.flatMap { $0(bound.definition) } ?? Bound.unbounded
            guard value != reference else { continue }
            result.append((bound.name, "\(value)"))
        }
        return result
    }

    private func reconstructEdgeTypeSpec(edgeType: EdgeType, graph: VGraph, base: Base?) throws(VError) -> String? {
        let isInBase = base?.has(edgeType: edgeType.id) ?? false
        let key = ItemKey(.edgeType, edgeType.id.description)
        var attrs: [(key: String, value: String)] = []

        // Read current attribute values (fall back to defaults on missing).
        let arrowHead: String =
            (try? graph.get(edgeType: edgeType.id, attribute: Attributes.Edge.arrowHead)) ?? Attributes.Edge.arrowHead.defaultValue
        let arrowTail: String =
            (try? graph.get(edgeType: edgeType.id, attribute: Attributes.Edge.arrowTail)) ?? Attributes.Edge.arrowTail.defaultValue
        let style: Attributes.Edge.StyleType =
            (try? graph.get(edgeType: edgeType.id, attribute: Attributes.Edge.style)) ?? Attributes.Edge.style.defaultValue
        let gColor: VColor =
            (try? graph.get(edgeType: edgeType.id, attribute: Attributes.Edge.color)) ?? Attributes.Edge.color.defaultValue
        let penwidth: Double = (try? graph.get(edgeType: edgeType.id, attribute: Attributes.Edge.penwidth)) ?? Attributes.Edge.penwidth.defaultValue
        let constraint: Bool =
            (try? graph.get(edgeType: edgeType.id, attribute: Attributes.Edge.constraint)) ?? Attributes.Edge.constraint.defaultValue
        let dir: String = (try? graph.get(edgeType: edgeType.id, attribute: Attributes.Edge.dir)) ?? Attributes.Edge.dir.defaultValue
        let headLabel: String =
            (try? graph.get(edgeType: edgeType.id, attribute: Attributes.Edge.headLabel)) ?? Attributes.Edge.headLabel.defaultValue
        let tailLabel: String =
            (try? graph.get(edgeType: edgeType.id, attribute: Attributes.Edge.tailLabel)) ?? Attributes.Edge.tailLabel.defaultValue
        let len: String = (try? graph.get(edgeType: edgeType.id, attribute: Attributes.Edge.len)) ?? Attributes.Edge.len.defaultValue
        let labelangle: String =
            (try? graph.get(edgeType: edgeType.id, attribute: Attributes.Edge.labelangle)) ?? Attributes.Edge.labelangle.defaultValue
        let labeldistance: String =
            (try? graph.get(edgeType: edgeType.id, attribute: Attributes.Edge.labeldistance)) ?? Attributes.Edge.labeldistance.defaultValue

        if isInBase {
            let base = base!
            let baseArrowHead = base.value(Attributes.Edge.arrowHead, of: key) ?? Attributes.Edge.arrowHead.defaultValue
            let baseArrowTail = base.value(Attributes.Edge.arrowTail, of: key) ?? Attributes.Edge.arrowTail.defaultValue
            let baseStyle = base.value(Attributes.Edge.style, of: key) ?? Attributes.Edge.style.defaultValue
            let baseGColor = base.value(Attributes.Edge.color, of: key) ?? Attributes.Edge.color.defaultValue
            let basePenwidth = base.value(Attributes.Edge.penwidth, of: key) ?? Attributes.Edge.penwidth.defaultValue
            let baseConstraint = base.value(Attributes.Edge.constraint, of: key) ?? Attributes.Edge.constraint.defaultValue
            let baseDir = base.value(Attributes.Edge.dir, of: key) ?? Attributes.Edge.dir.defaultValue
            let baseHeadLabel = base.value(Attributes.Edge.headLabel, of: key) ?? Attributes.Edge.headLabel.defaultValue
            let baseTailLabel = base.value(Attributes.Edge.tailLabel, of: key) ?? Attributes.Edge.tailLabel.defaultValue
            let baseLen = base.value(Attributes.Edge.len, of: key) ?? Attributes.Edge.len.defaultValue
            let baseLabelangle = base.value(Attributes.Edge.labelangle, of: key) ?? Attributes.Edge.labelangle.defaultValue
            let baseLabeldistance = base.value(Attributes.Edge.labeldistance, of: key) ?? Attributes.Edge.labeldistance.defaultValue

            if arrowHead != baseArrowHead { attrs.append(("arrowHead", arrowHead)) }
            if arrowTail != baseArrowTail { attrs.append(("arrowTail", arrowTail)) }
            if style != baseStyle { attrs.append(("style", style.asString)) }
            if gColor != baseGColor { attrs.append(("color", gColor.hexString)) }
            if penwidth != basePenwidth { attrs.append(("penwidth", formatDouble(penwidth))) }
            if constraint != baseConstraint { attrs.append(("constraint", constraint ? "true" : "false")) }
            if dir != baseDir { attrs.append(("dir", dir)) }
            if headLabel != baseHeadLabel { attrs.append(("headLabel", headLabel)) }
            if tailLabel != baseTailLabel { attrs.append(("tailLabel", tailLabel)) }
            if len != baseLen { attrs.append(("len", len)) }
            if labelangle != baseLabelangle { attrs.append(("labelangle", labelangle)) }
            if labeldistance != baseLabeldistance { attrs.append(("labeldistance", labeldistance)) }

            // Deliberately no early return here — see the isEmpty check below the
            // bound append.
        } else {
            if arrowHead != Attributes.Edge.arrowHead.defaultValue { attrs.append(("arrowHead", arrowHead)) }
            if arrowTail != Attributes.Edge.arrowTail.defaultValue { attrs.append(("arrowTail", arrowTail)) }
            if style != Attributes.Edge.style.defaultValue { attrs.append(("style", style.asString)) }
            if gColor != Attributes.Edge.color.defaultValue { attrs.append(("color", gColor.hexString)) }
            if penwidth != Attributes.Edge.penwidth.defaultValue { attrs.append(("penwidth", formatDouble(penwidth))) }
            if constraint != Attributes.Edge.constraint.defaultValue { attrs.append(("constraint", constraint ? "true" : "false")) }
            if dir != Attributes.Edge.dir.defaultValue { attrs.append(("dir", dir)) }
            if headLabel != Attributes.Edge.headLabel.defaultValue { attrs.append(("headLabel", headLabel)) }
            if tailLabel != Attributes.Edge.tailLabel.defaultValue { attrs.append(("tailLabel", tailLabel)) }
            if len != Attributes.Edge.len.defaultValue { attrs.append(("len", len)) }
            if labelangle != Attributes.Edge.labelangle.defaultValue { attrs.append(("labelangle", labelangle)) }
            if labeldistance != Attributes.Edge.labeldistance.defaultValue { attrs.append(("labeldistance", labeldistance)) }
        }

        attrs.append(
            contentsOf: boundAttrs(
                Bound.edgeBounds,
                read: { definition in try? graph.get(edgeType: edgeType.id, attribute: definition) },
                base: base.map { base in { definition in base.value(definition, of: key) } }))

        if isInBase && attrs.isEmpty { return nil }

        var line = "edge type: \(edgeType.id)  from: \(edgeType.from.id)  to: \(edgeType.to.id)"
        if !attrs.isEmpty {
            // Values in `attrs` are raw: quoting is decided here and only here.
            let attrStr = attrs.map { "\($0.key): \(quoteIfNeeded($0.value))" }.joined(separator: ", ")
            line += " [\(attrStr)]"
        }
        return line
    }

    private func formatDouble(_ value: Double) -> String {
        return "\(value)"
    }

    private func quoteIfNeeded(_ value: String) -> String {
        needsQuoting(value) ? "\"\(StringEscaping.escape(value))\"" : value
    }

    private func vnotationKeyName(for def: AttributeDefinition) -> String {
        if def.id == Attributes.Group.layoutDirection.id { return "layout" }
        return def.vglKey
    }

    /// Enum types use the `.value` property (Swift case name) instead of the readableName.
    private func vnotationValue(_ storedValue: String, for def: AttributeDefinition) -> String {
        if def.id == Attributes.Group.layoutDirection.id,
            let parsed = try? LayoutDirection.fromString(storedValue)
        {
            return parsed.value
        }
        if def.id == Attributes.Group.diagramLogic.id,
            let parsed = try? DiagramLogic.fromString(storedValue)
        {
            return parsed.value
        }
        return storedValue
    }

    /// Whether a value has to be written quoted. `Parser.value()` takes a quoted
    /// label, one bare `.identifier` or one bare `.number` — so asking the lexer
    /// keeps the two in step, where a blacklist of bad characters could only ever
    /// be as complete as the last bug found against it (`VGLExporterQuotingTest`).
    private func needsQuoting(_ value: String) -> Bool {
        let tokens = Lexer(source: value).scanTokens()
        guard tokens.count == 2 else { return true }  // one token plus .eof
        let token = tokens[0]
        guard token.type == .identifier || token.type == .number else { return true }
        // A trailing `//` comment is dropped rather than tokenised, so `a//b`
        // also reaches here as a single token; the span check catches it.
        return token.start != 0 || token.end != value.count
    }

}
