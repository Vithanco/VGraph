import VGraph

/// Maps old VGL attribute names to canonical names for backward compatibility.
/// `rankdir`/`layout`/`labelloc` are graphviz-style names from early VGL versions;
/// `diagramlogic` is an old all-lowercase form.
func resolveLegacyAttributeName(_ name: String, for target: AttributeTarget = .graph) -> String {
    switch name.lowercased() {
    case "rankdir", "layout": return Attributes.Group.layoutDirection.name
    case "labelloc": return Attributes.Group.labelocation.name
    case "diagramlogic": return Attributes.Group.diagramLogic.name
    // Stated rather than left to `find(attributeByName:)`, whose last resort is a
    // substring match over a Dictionary — "color" would reach "backgroundColor" by
    // accident, in whatever order the dictionary happened to enumerate.
    case "color" where target == .node: return Attributes.Node.backgroundColor.name
    // The native renderer draws a group from its border and background, so a
    // group's `color` is its background.
    case "color" where target == .graph: return Attributes.Group.backgroundColor.name
    default: return name
    }
}

public class VGraphParser<Logger: ForLogMessages>: ForParseAGraph, ForHighlightVGL {

    var edgeIds: Int
    var groupIds: Int
    var logger: Logger
    /// Runtime notation registry populated from `vnotation` declarations parsed in the same source.
    /// Stores concrete `DynamicNotation` values, avoiding any `as?` cast through existentials.
    var dynamicNotations: [String: DynamicNotation] = [:]

    public init(edgeIds: Int = 100001, groupIds: Int = 200001, logger: Logger) {
        self.edgeIds = edgeIds
        self.groupIds = groupIds
        self.logger = logger
    }

    public func parseGraphToDot(vgraph: String) throws(VError) -> String {
        do {
            let graph = try parse(source: vgraph)
            return "we have \(graph.nodes.count) nodes and \(graph.edges.count) edges\n\n"
        } catch let error {
            return ("Unexpected error: \(error).")
        }
    }

    public func parse(source: String) throws(VError) -> VGraph {
        // Reset per-parse state so vnotation declarations don't leak between calls.
        dynamicNotations = [:]

        var graph: VGraph = VGraph()
        graph = try graph.defineStandardAttributes()
        let ast = try parseToAST(source)
        return try convert(from: ast, to: graph)
    }

    /// The bare `catch` (no `as` pattern) is deliberate: under typed throws,
    /// `error` is inferred as the concrete `VParserError` because
    /// `parse(source:)` is `throws(VParserError)`. Writing
    /// `catch let error as VParserError` instead — a redundant typed cast —
    /// triggered a `swift-frontend` SILGen crash on Swift 6.3.2-RELEASE
    /// (later turned into "INTERNAL ERROR: feature not implemented: throw
    /// conversion from 'VParserError' to 'VError'" on `main`). Keeping the
    /// catch bare avoids the synthesised conversion path entirely.
    private func parseToAST(_ vgraph: String) throws(VError) -> ASTNode {
        do {
            return try parseToASTNode(source: vgraph)
        } catch {
            throw VError.parsingError(error.description)
        }
    }

    func convert(from: ASTNode, to graph: VGraph? = nil) throws(VError) -> VGraph {
        let rootGroup = Group(rawValue: "vithanco.vgraph.rootGroup.only.for.internal.use")
        return try convert(from: from, graph: graph ?? VGraph(), stack: ParserStack(currentGroup: rootGroup))
    }

    func convert(from: ASTNode, graph: VGraph, stack: ParserStack) throws(VError) -> VGraph {
        var result = graph
        switch from {
        case .file(let vnotations, let document, let views):
            for vn in vnotations {
                let notation = try buildDynamicNotation(from: vn)
                dynamicNotations[notation.id.id] = notation
            }
            result = try convert(from: document, graph: result, stack: stack)
            for view in views {
                result = try convert(view: view, to: result)
            }
            return result

        case .document(let id, let type, let extensions, let label, let children, let comments):

            if let resolved = try applyNotation(named: type, to: result) {
                result = resolved
                // Store extends info for export reconstruction. `dynamicNotations`
                // now stores concrete `DynamicNotation` values, so no `as?` cast.
                // Use `baseVglName` (the VGL-facing name the user typed) so the
                // re-parser can re-resolve it through the registry.
                if let dynNotation = dynamicNotations[type], let vglName = dynNotation.baseVglName {
                    result = result.extending(notation: vglName)
                }
            } else {
                logger.error(
                    "[Parser] ❌ Unknown notation '\(type)'. Valid notations are: \(NotationRegistry.validNames)"
                )
            }

            // Two-phase extension registration:
            // Phase 1 — register all extension node types before any edge types.
            for extName in extensions {
                result = try applyExtensionNodeTypes(extName, to: result)
            }
            // Phase 2 — register all extension edge types (all node types now visible).
            for extName in extensions {
                result = try applyExtensionEdgeTypes(extName, to: result)
            }

            for statement in children {
                result = try convert(from: statement, graph: result, stack: stack)
            }
            if let label = label {
                result = try result.set(graphAttribute: Attributes.Group.label.attribute(label))
            }
            result = try result.set(graphAttribute: Attributes.Group.Id.attribute(id))
            result = result.using(notation: type).using(extensions: extensions)
            if let leading = comments.leading {
                result = try result.set(graphAttribute: Attributes.Group.comment.attribute(leading))
            }
            if let trailing = comments.trailing {
                result = try result.set(graphAttribute: Attributes.Group.trailingComment.attribute(trailing))
            }

        case .node(let id, type: let typeName, let label, let attributes, let comments):
            let node = Node(string: id)

            let nodeType: NodeType
            if result.has(nodeTypeName: typeName) {
                nodeType = NodeType(string: typeName)
            } else {
                logger.warn("[Parser] Node '\(id)': ⚠️ Node type '\(typeName)' not found")
                result = try result.ensureUnknownNodeType()
                nodeType = NodeType.unknown
            }

            result = try result.add(node: node, type: nodeType, group: stack.currentGroup)
            // Use the given label if present and non-empty; otherwise fall back
            // to the node id, which is far more useful than the generic default
            // ("Change Me") and easier to locate in the drawing. The id-derived
            // label is then emitted explicitly on export.
            if let label = label, !label.isEmpty {
                result = try result.set(node: node, attribute: Attributes.Node.label.attribute(fromString: label))
            } else {
                result = try result.set(node: node, attribute: Attributes.Node.label.attribute(fromString: id))
            }
            let newStack = ParserStack(currentNode: node, currentGroup: stack.currentGroup)
            for attribute in attributes {
                result = try convert(from: attribute, graph: result, stack: newStack)
            }
            if let leading = comments.leading {
                result = try result.set(node: node, attribute: Attributes.Node.comment.attribute(leading))
            }
            if let trailing = comments.trailing {
                result = try result.set(node: node, attribute: Attributes.Node.trailingComment.attribute(trailing))
            }

        case .attribute(id: let key, let value):
            if let currentNode = stack.currentNode {
                let resolvedKey = resolveLegacyAttributeName(key, for: .node)
                guard let def = result.find(attributeByName: resolvedKey, for: .node) else {
                    throw VError.attributeNotFound(Attribute.Id(rawValue: key))
                }
                try refuseComputed(def, named: key)
                // Here rather than in the style resolver, which can only skip it —
                // leaving a node indistinguishable from one with no colour at all.
                if def.id == Attributes.Node.backgroundColor.id || def.id == Attributes.Node.fontColor.id,
                    (try? VColor.fromString(value)) == nil
                {
                    throw VError.conversionError(
                        from: value, to: "a hex colour (\"#b6e6bd\") or an SVG colour name (\"cornflowerblue\")")
                }
                result = try result.set(node: currentNode, attribute: def.attribute(fromString: stored(value, for: def)))
            } else if let currentEdge = stack.currentEdge {
                let resolvedKey = resolveLegacyAttributeName(key, for: .edge)
                guard let def = result.find(attributeByName: resolvedKey, for: .edge) else {
                    throw VError.attributeNotFound(Attribute.Id(rawValue: key))
                }
                try refuseComputed(def, named: key)
                result = try result.set(edge: currentEdge, attribute: def.attribute(fromString: stored(value, for: def)))
            } else if let currentGroup = stack.currentGroup {
                guard let def = attribute(named: key, among: result.attributeTargets(of: currentGroup), in: result) else {
                    throw VError.attributeNotFound(Attribute.Id(rawValue: key))
                }
                try refuseComputed(def, named: key)
                result = try result.set(group: currentGroup, attribute: def.attribute(fromString: stored(value, for: def)))
            }

        case .edge(let fromId, let toId, let type, let label, let attributes, let comments):
            edgeIds += 1
            let eId = String(edgeIds)
            let edge = Edge(string: eId, from: fromId, to: toId)

            var edgeType: EdgeType? = nil

            if let typeName = type, result.has(edgeTypeId: typeName) {
                edgeType = result.get(edgeType: EdgeType.Id(string: typeName))
            }

            if edgeType == nil, type == nil {
                let fromType = try typeOfEnd(fromId, in: result)
                let toType = try typeOfEnd(toId, in: result)
                let fromNodeType = fromType.id
                let toNodeType = toType.id

                let allPossibleEdgeTypes = result.edgeTypes(holdingFrom: fromType, to: toType)

                if allPossibleEdgeTypes.count == 1 {
                    edgeType = allPossibleEdgeTypes.first
                } else if allPossibleEdgeTypes.count > 1 {
                    // Multiple edge types exist - ambiguous, fall through to create unknown
                    // User should specify which edge type explicitly
                    let typeIds = allPossibleEdgeTypes.map { $0.id.description }.joined(separator: ", ")
                    logger.warn("[Parser] ⚠️ Multiple edge types found (\(allPossibleEdgeTypes.count)): \(typeIds)")
                    edgeType = nil
                } else {
                    logger.warn("[Parser] ⚠️ No edge type found for \(fromNodeType) -> \(toNodeType)")
                    edgeType = nil
                }
            }

            if let et = edgeType {
                do {
                    result = try result.add(edge: edge, edgeType: et)
                } catch VError.EdgeTypeWrong {
                    edgeType = nil
                }
            }

            if edgeType == nil {
                let fromNodeType = (try? result.nodeType(for: Node(string: fromId))) ?? NodeType.unknown
                let toNodeType = (try? result.nodeType(for: Node(string: toId))) ?? NodeType.unknown
                let unknownEdgeType: EdgeType
                (result, unknownEdgeType) = try result.ensureUnknownEdgeType(from: fromNodeType, to: toNodeType)
                result = try result.add(edge: edge, edgeType: unknownEdgeType)
            }

            let newStack = ParserStack(currentEdge: edge)
            for attribute in attributes {
                result = try convert(from: attribute, graph: result, stack: newStack)
            }

            if let label = label {
                result = try result.set(edge: edge, attribute: Attributes.Edge.label.attribute(fromString: label))
            }
            if let leading = comments.leading {
                result = try result.set(edge: edge, attribute: Attributes.Edge.comment.attribute(leading))
            }
            if let trailing = comments.trailing {
                result = try result.set(edge: edge, attribute: Attributes.Edge.trailingComment.attribute(trailing))
            }

        case .group(let id, let type, let label, let isFolded, let children, let comments):
            groupIds += 1
            let group = Group(rawValue: String(id))
            result = try declaring(
                group, type: type, label: label, isFolded: isFolded, comments: comments,
                in: result, childOf: stack.currentGroup)
            let newStack = ParserStack(currentGroup: group)
            for child in children {
                result = try convert(from: child, graph: result, stack: newStack)
            }

        case .vnotationDecl:
            // vnotationDecl nodes are consumed at the .file level; reaching here is a no-op.
            break

        case .metagraph(let notationName, let label):
            result = try buildMetagraph(
                notationName: notationName,
                label: label,
                graph: result,
                stack: stack
            )

        case .metadescription(let notationName, let label):
            // The same diagram as `metagraph`. The document that describes the
            // notation is not part of the graph: `describeNotation` renders it.
            result = try buildMetagraph(
                notationName: notationName,
                label: label,
                graph: result,
                stack: stack
            )
        // If the notation name is unknown, buildMetagraph already logged.
        }
        return result
    }

    /// Out of `convert`, as `declaring` is, to keep its recursive frame small.
    private func typeOfEnd(_ id: String, in graph: VGraph) throws(VError) -> NodeType {
        guard let type = graph.typedGraph.nodeType(for: Node(string: id)) else {
            throw VError.nodeWithoutNodeType(Node(string: id))
        }
        return type
    }

    /// Out of `convert` so its frame stays small: `convert` recurses once per
    /// nesting level, and a test runs on a 512 KB stack.
    private func declaring(
        _ group: Group, type: String?, label: String?, isFolded: Bool, comments: Comments,
        in graph: VGraph, childOf parent: Group?
    ) throws(VError) -> VGraph {
        let id = group.id.id
        var result = try graph.add(group: group, childOf: parent)
        result = try result.set(group: group, attribute: Attributes.Group.Id.attribute(fromString: id))
        if let type = type, !type.isEmpty, result.has(nodeTypeName: type) {
            result = try result.typing(group: group, as: NodeType(string: type))
        } else if let type = type, !type.isEmpty {
            let groupType: GroupType
            if result.has(groupTypeName: type) {
                groupType = GroupType(string: type)
            } else {
                logger.warn("[Parser] Group '\(id)': ⚠️ Group type '\(type)' not found")
                result = try result.ensureUnknownGroupType()
                groupType = GroupType.unknown
            }
            result = try result.typing(group: group, as: groupType)
        }
        let detailed = result.isDetailed(group)
        // As for a node, an absent label means the id.
        if detailed, label?.isEmpty ?? true {
            result = try result.set(label: id, on: .group(group))
        } else if let label = label {
            result = try result.set(label: label, on: .group(group))
        }
        if isFolded {
            result = try result.set(group: group, attribute: Attributes.Group.isFolded.attribute(true))
        }
        if let leading = comments.leading {
            let comment = detailed ? Attributes.Node.comment : Attributes.Group.comment
            result = try result.set(group: group, attribute: comment.attribute(leading))
        }
        if let trailing = comments.trailing {
            let comment = detailed ? Attributes.Node.trailingComment : Attributes.Group.trailingComment
            result = try result.set(group: group, attribute: comment.attribute(trailing))
        }
        return result
    }

    /// A name the model lacks is kept all the same: stored, written back, affecting nothing.
    private func convert(view: VViewDecl, to graph: VGraph) throws(VError) -> VGraph {
        var result = try graph.declaring(view: ViewDeclaration(name: view.name, label: view.label, rules: view.rules))
        for (key, value) in view.attrs {
            let attribute = try viewAttribute(key, value, for: [.graph], in: result)
            result = try result.settingInView(view.name, attribute, for: .root)
        }
        for statement in view.statements {
            let kind: ItemKind
            switch (statement.target, statement.isType) {
            case (.node, false): kind = .node
            case (.node, true): kind = .nodeType
            case (.group, false): kind = .group
            case (.group, true): kind = .groupType
            }
            for (name, value) in statement.attrs {
                for id in statement.names {
                    let attribute = try viewAttribute(name, value, for: targets(of: ItemKey(kind, id), in: result), in: result)
                    result = try result.settingInView(view.name, attribute, for: ItemKey(kind, id))
                }
            }
        }
        return result
    }

    /// A group named in a view speaks its own namespace, which a detailed node
    /// widens to a node's; a group type stays a group's. A node type also
    /// stands for its detailed nodes, which fold (ADR-0032).
    private func targets(of key: ItemKey, in graph: VGraph) -> [AttributeTarget] {
        switch key.kind {
        case .node: return [.node]
        case .nodeType: return [.node, .graph]
        case .group: return graph.attributeTargets(of: Group(rawValue: key.id))
        case .groupType, .root, .edge, .edgeType: return [.graph]
        }
    }

    private func viewAttribute(
        _ key: String, _ value: String, for targets: [AttributeTarget], in graph: VGraph
    ) throws(VError) -> Attribute {
        guard let definition = attribute(named: key, among: targets, in: graph), targets == [.graph] || !definition.isDiagramOnly else {
            if targets != [.graph], graph.find(attributeByName: key, for: .graph) != nil {
                throw VError.parsingError("'\(key)' applies to the whole diagram; set it in the view's header")
            }
            throw VError.attributeNotFound(Attribute.Id(rawValue: key))
        }
        guard definition.category == .presentation else {
            throw VError.parsingError("'\(key)' is not a presentation attribute; a view sets presentation only")
        }
        if definition.id == Attributes.Node.backgroundColor.id || definition.id == Attributes.Node.fontColor.id,
            (try? VColor.fromString(value)) == nil
        {
            throw VError.conversionError(
                from: value, to: "a hex colour (\"#b6e6bd\") or an SVG colour name (\"cornflowerblue\")")
        }
        if definition.typeAsString == Bool.typeName, value != "true", value != "false" {
            throw VError.parsingError("'\(key)' must be true or false, not '\(value)'")
        }
        return try definition.attribute(fromString: value)
    }

    private func attribute(
        named key: String, among targets: [AttributeTarget], in graph: VGraph
    ) -> AttributeDefinition? {
        graph.find(attributeAmong: targets.map { (name: resolveLegacyAttributeName(key, for: $0), target: $0) })
    }

    /// Only comments need adjusting — `[comment: "hello"]` is a legal way to
    /// write one, and the stored form is always marked VGL.
    private func stored(_ value: String, for def: AttributeDefinition) -> String {
        CommentAttributes.holdsAComment(def.id) ? CommentAttributes.canonical(value) : value
    }

    /// Populate `graph` with one node per registered NodeType and one edge per
    /// registered EdgeType for the named notation, then set the standard metagraph
    /// graph-level attributes (label, id, notation). Returns the graph unchanged
    /// (with an error logged) when the notation cannot be resolved.
    ///
    /// Shared by the `.metagraph` and `.metadescription` AST cases.
    private func buildMetagraph(
        notationName: String,
        label: String?,
        graph: VGraph,
        stack: ParserStack
    ) throws(VError) -> VGraph {
        var result = graph
        guard let resolved = try applyNotation(named: notationName, to: result) else {
            logger.error(
                "[Parser] ❌ Unknown notation '\(notationName)' for metagraph. Valid notations are: \(NotationRegistry.validNames)"
            )
            return result
        }
        result = resolved

        // Add one node per registered NodeType (skip synthetic unknown types).
        // Node IDs are prefixed with `_meta_` so they don't collide with NodeType IDs
        // in the shared attribute keyspace (VError.idCollision would otherwise fire).
        for nt in result.nodeTypes where !nt.id.hasPrefix(NodeType.unknownPrefix) {
            let node = Node(string: "_meta_\(nt.id)")
            result = try result.add(node: node, type: nt, group: stack.currentGroup)
            result = try result.set(node: node, attribute: Attributes.Node.label.attribute(fromString: nt.id))
        }

        for et in result.edgeTypes where !et.isUnknown {
            edgeIds += 1
            let eId = String(edgeIds)
            let edge = Edge(
                id: Edge.Id(string: eId),
                from: Node(string: "_meta_\(et.from.id)"),
                to: Node(string: "_meta_\(et.to.id)"))
            result = try result.add(edge: edge, edgeType: et)
        }

        // A detailing is no relationship, so it gets an edge type of its own
        // that the notation never declares.
        for nt in result.nodeTypes {
            for detailType in result.detailTypes(of: nt) {
                let detailedBy = EdgeType(
                    string: "detailedBy__\(nt.id)__\(detailType.id)", from: nt.id, to: detailType.id)
                edgeIds += 1
                let edge = Edge(
                    id: Edge.Id(string: String(edgeIds)),
                    from: Node(string: "_meta_\(nt.id)"),
                    to: Node(string: "_meta_\(detailType.id)"))
                result = try result.add(edgeType: detailedBy).add(edge: edge, edgeType: detailedBy)
                result = try result.set(edge: edge.id, attribute: Attributes.Edge.label.attribute("detailed by"))
                result = try result.set(edge: edge.id, attribute: Attributes.Edge.style.attribute(.dashed))
            }
        }

        let effectiveLabel = label ?? "\(notationName) Meta Model"
        result = try result.set(graphAttribute: Attributes.Group.label.attribute(effectiveLabel))
        result = try result.set(graphAttribute: Attributes.Group.Id.attribute(notationName))
        return result.using(notation: notationName)
    }

    /// Resolve a notation by name (dynamic first, then built-in registry) and apply it to the graph.
    /// Returns `nil` if the notation was not found. Dispatches through value-type
    /// closures only — no metatypes, no existentials.
    private func applyNotation(named name: String, to graph: VGraph) throws(VError) -> VGraph? {
        if let notation = dynamicNotations[name] {
            return try notation.addNotation(addTo: graph)
        } else if let entry = NotationRegistry.entry(for: name) {
            return try graph.placing(entry.content, in: .builtin)
        }
        return nil
    }

    /// What the Display pipeline computes is never written in a document: a
    /// file that could author it would parse into a graph it cannot describe.
    private func refuseComputed(_ definition: AttributeDefinition, named key: String) throws(VError) {
        guard definition.category == .computed else { return }
        throw VError.parsingError("'\(key)' is computed when the diagram is drawn and cannot be written in VGL")
    }

    private func applyExtensionNodeTypes(_ name: String, to graph: VGraph) throws(VError) -> VGraph {
        guard let ext = NotationRegistry.extensionEntry(for: name) else {
            let valid = NotationRegistry.extensionEntries.map { $0.id }.joined(separator: ", ")
            logger.error("[Parser] ❌ Unknown extension '\(name)'. Valid extensions are: \(valid)")
            return graph
        }
        return try graph.placing(ext.nodeContent, in: .builtin)
    }

    private func applyExtensionEdgeTypes(_ name: String, to graph: VGraph) throws(VError) -> VGraph {
        guard let ext = NotationRegistry.extensionEntry(for: name) else {
            return graph
        }
        return try graph.placing(ext.edgeContent(graph.nodeTypes), in: .builtin)
    }

    // MARK: - Dynamic notation builder

    private func buildDynamicNotation(from node: ASTNode) throws(VError) -> DynamicNotation {
        guard
            case .vnotationDecl(
                let name, let extendsName, let graphAttrs, let nodeTypeDecls, let edgeTypeDecls, let groupTypeDecls,
                let iconDecls, let qualityCheckStrs, let transformStrs) = node
        else {
            throw VError.parsingError("Internal error: expected .vnotationDecl AST node")
        }

        // Resolve base notation (for extends clause).
        let base: NotationEntry?
        if let extName = extendsName {
            guard let entry = NotationRegistry.entry(for: extName) else {
                logger.error("[Parser] ❌ vnotation '\(name)' extends unknown notation '\(extName)'. Valid: \(NotationRegistry.validNames)")
                throw VError.parsingError("vnotation '\(name)' extends unknown notation '\(extName)'")
            }
            base = entry
        } else {
            base = nil
        }

        // Build NodeTypeSpec array.  nodeStyle is optional here; validated later
        // (required for new types, optional for overrides of inherited types).
        let nodeTypeSpecs: [NodeTypeSpec] = nodeTypeDecls.map { decl in
            var attrs: [String: String] = [:]
            for (key, value) in decl.attrs { attrs[key] = value }
            let nodeStyle = attrs.removeValue(forKey: "nodeStyle")
            return NodeTypeSpec(name: decl.name, nodeStyle: nodeStyle, rawAttrs: attrs, detailedBy: decl.detailedBy)
        }

        let edgeTypeSpecs: [EdgeTypeSpec] = edgeTypeDecls.map { decl in
            var attrs: [String: String] = [:]
            for (key, value) in decl.attrs { attrs[key] = value }
            return EdgeTypeSpec(id: decl.id, from: decl.from, to: decl.to, rawAttrs: attrs)
        }

        var icons: [(name: String, artwork: IconArtwork)] = []
        for decl in iconDecls {
            icons.append((name: decl.name, artwork: decl.artwork))
        }

        let qualityCheckSpecs = qualityCheckStrs.map { QualityCheckSpec.parse($0) }

        return DynamicNotation(
            id: Identifier(rawValue: name),
            nodeTypeSpecs: nodeTypeSpecs,
            edgeTypeSpecs: edgeTypeSpecs,
            groupTypes: groupTypeDecls.map { GroupType(string: $0.name) },
            groupTypeAttrs: groupTypeAttrs(groupTypeDecls),
            graphAttrs: graphAttrs,
            baseEntry: base,
            baseVglName: extendsName,
            icons: icons,
            qualityCheckSpecs: qualityCheckSpecs,
            transformNames: transformStrs
        )
    }

    /// A group type declared twice gets both declarations' attributes, the later
    /// winning where they name the same key.
    private func groupTypeAttrs(_ decls: [VNotationGroupTypeDecl]) -> [GroupType: [String: String]] {
        let declared = decls.filter { !$0.attrs.isEmpty }.map { decl in
            (
                GroupType(string: decl.name),
                Dictionary(decl.attrs.map { ($0.key, $0.value) }, uniquingKeysWith: { _, later in later })
            )
        }
        return Dictionary(declared, uniquingKeysWith: { earlier, later in earlier.merging(later) { _, new in new } })
    }

    func parseToASTNode(source: String) throws(VParserError) -> ASTNode {
        let lexer = Lexer(source: source)
        let tokens = lexer.scanTokens()
        let parser = Parser(tokens: tokens, comments: lexer.comments)
        return try parser.parse()
    }

    // MARK: - Syntax highlighting

    private var highlightNotationNames: Set<String> {
        Set(NotationRegistry.entries.map { $0.id } + NotationRegistry.extensionEntries.map { $0.id })
    }

    /// Parse-free highlight for the current keystroke; never fails.
    public func lexicalHighlightHTML(source: String) -> String {
        let tokens = Lexer(source: source).scanTokens()
        let spans = classifyLexical(tokens: tokens, notationNames: highlightNotationNames)
        return buildHighlightHTML(source: source, tokens: spans)
    }

    /// Parse-backed highlight: identifier roles, unknown types flagged, and (when
    /// a `report` is given) its locatable errors/warnings overlaid as tooltip
    /// markers. On a syntax error, colors lexically and marks the offending token.
    public func semanticHighlightHTML(source: String, report: QualityReport? = nil) -> String {
        let tokens = Lexer(source: source).scanTokens()
        let parser = Parser(tokens: tokens)
        do {
            _ = try parser.parse()
        } catch {
            // Drop the lexical span on the offending token so the marker wins.
            var spans = classifyLexical(tokens: tokens, notationNames: highlightNotationNames)
            if let range = parser.currentErrorRange {
                spans.removeAll { $0.start == range.start }
                spans.append(
                    VGLSemanticToken(start: range.start, length: range.length, role: .syntaxError))
            }
            return buildHighlightHTML(source: source, tokens: spans)
        }

        // Best-effort: skip validity coloring if the graph can't be built.
        var validNodeTypeNames: Set<String>? = nil
        var validGroupTypeNames: Set<String>? = nil
        var validIconNames: Set<String>? = nil
        var knownNodeIds: Set<String>? = nil
        var knownGroupIds: Set<String>? = nil
        if let graph = try? parse(source: source) {
            knownNodeIds = Set(graph.nodes.map { $0.id })
            knownGroupIds = Set(graph.groups.map { $0.id.id })
            // What the document declared plus what VGraph ships — the same two
            // sources `graph.artwork(forIcon:)` reads, in the same order.
            var iconNames = Set(BuiltinIcons.names)
            for name in graph.declaredIcons.keys { iconNames.insert(name) }
            validIconNames = iconNames
            validNodeTypeNames = Set(
                graph.nodeTypes
                    .map { $0.id }
                    .filter { !$0.hasPrefix(NodeType.unknownPrefix) }
            )
            validGroupTypeNames = Set(
                graph.groupTypes
                    .map { $0.id }
                    .filter { !$0.hasPrefix(GroupType.unknownPrefix) }
            )
        }

        let spans = classifySemantic(
            tokens: tokens,
            idRoles: parser.semanticIdentifiers,
            validNodeTypeNames: validNodeTypeNames,
            validGroupTypeNames: validGroupTypeNames,
            groupTypeSlots: parser.groupTypeSlots,
            iconNames: parser.iconNameSpans,
            validIconNames: validIconNames,
            viewNames: parser.viewNames,
            knownNodeIds: knownNodeIds,
            knownGroupIds: knownGroupIds
        )

        let markers = report.map { diagnosticMarkers(from: $0, parser: parser) } ?? []
        return buildHighlightHTML(source: source, tokens: spans, markers: markers)
    }

    /// Map located findings to spans, grouping ones that share a span into a
    /// single marker (one tooltip lists them all; any error makes it an error).
    private func diagnosticMarkers(from report: QualityReport, parser: Parser) -> [VGLSemanticToken] {
        // Tuple, not a nested struct — Swift forbids nesting a type in a generic method.
        var byRange: [String: (start: Int, length: Int, isError: Bool, messages: [String])] = [:]
        for msg in report.messages where msg.severity == .error || msg.severity == .warning {
            let span: (start: Int, length: Int)?
            switch msg.target {
            case .graph: span = nil
            case .node(let id): span = parser.nodeSpans[id]
            case .edge(let from, let to): span = parser.edgeSpans[Parser.edgeSpanKey(from: from, to: to)]
            }
            guard let span else { continue }
            let key = "\(span.start):\(span.length)"
            if var group = byRange[key] {
                group.messages.append(msg.message)
                group.isError = group.isError || msg.severity == .error
                byRange[key] = group
            } else {
                byRange[key] = (span.start, span.length, msg.severity == .error, [msg.message])
            }
        }
        return byRange.values.map { group in
            VGLSemanticToken(
                start: group.start,
                length: group.length,
                role: group.isError ? .diagError : .diagWarning,
                title: group.messages.joined(separator: "\n"))
        }
    }

    func generateSource(from ast: ASTNode) -> String {
        func generateNode(_ node: ASTNode, indent: Int = 0) -> String {
            let indentation = String(repeating: "  ", count: indent)
            var result = ""

            switch node {
            case .document(let id, let type, let extensions, let label, let children, _):
                let typeDecl = ([type] + extensions).joined(separator: ", ")
                result += "vgraph \(id): \(typeDecl)"
                if let label = label, !label.isEmpty {
                    result += " \"\(label)\""
                }
                result += " {\n"

                for child in children {
                    result += generateNode(child, indent: indent + 1)
                }

                result += indentation + "}"

            case .group(let id, let type, let label, let isFolded, let children, _):
                if isFolded {
                    result += indentation + "folded group \(id)"
                } else {
                    result += indentation + "group \(id)"
                }
                if let type = type, !type.isEmpty {
                    result += ": \(type)"
                }
                if let label = label, !label.isEmpty {
                    result += " \"\(label)\""
                }
                result += " {\n"

                for child in children {
                    result += generateNode(child, indent: indent + 1)
                }

                result += indentation + "};\n"

            case .node(let id, let type, let label, let attributes, _):
                result += indentation + "node \(id): \(type)"
                if let label = label, !label.isEmpty {
                    result += " \"\(label)\""
                }
                result += " {\n"

                for attr in attributes {
                    result += generateNode(attr, indent: indent + 1)
                }

                result += indentation + "};\n"

            case .edge(let sourceId, let targetId, let type, let label, let attributes, _):
                result += indentation + "edge \(sourceId) -> \(targetId)"
                if let type = type, !type.isEmpty {
                    result += ": \(type)"
                }
                if let label = label, !label.isEmpty {
                    result += " \"\(label)\""
                }
                result += " {\n"

                for attr in attributes {
                    result += generateNode(attr, indent: indent + 1)
                }

                result += indentation + "};\n"

            case .attribute(let id, let value):
                result += indentation + "\(id): \(value);\n"

            case .metagraph(let notationName, let label):
                result += indentation + "metagraph \(notationName)"
                if let label = label, !label.isEmpty {
                    result += " \"\(label)\""
                }
                result += "\n"

            case .metadescription(let notationName, let label):
                result += indentation + "metadescription \(notationName)"
                if let label = label, !label.isEmpty {
                    result += " \"\(label)\""
                }
                result += "\n"

            case .file(let vnotations, let document, _):
                for vn in vnotations { result += generateNode(vn, indent: indent) }
                result += generateNode(document, indent: indent)

            case .vnotationDecl(
                let name, let extendsNotation, let graphAttrs, let nodeTypes, let edgeTypes, let groupTypes, let icons,
                let qualityChecks, let transforms):
                result += indentation + "vnotation \(name)"
                if let ext = extendsNotation { result += " extends \(ext)" }
                result += " {\n"
                for (key, value) in graphAttrs {
                    result += indentation + "  \(key): \(value);\n"
                }
                for icon in icons {
                    result +=
                        indentation
                        + "  icon \(icon.name) [viewBox: \"\(icon.artwork.viewBox)\"; path: \"\(icon.artwork.path)\"];\n"
                }
                for nt in nodeTypes {
                    let attrsStr = nt.attrs.map { "\($0.key): \($0.value)" }.joined(separator: "; ")
                    result += indentation + "  node type: \(nt.name) [\(attrsStr)];\n"
                }
                for et in edgeTypes {
                    let attrsStr = et.attrs.map { "\($0.key): \($0.value)" }.joined(separator: "; ")
                    result += indentation + "  edge type: \(et.id) from: \(et.from) to: \(et.to)"
                    if !attrsStr.isEmpty { result += " [\(attrsStr)]" }
                    result += ";\n"
                }
                for groupType in groupTypes {
                    let attrsStr = groupType.attrs.map { "\($0.key): \($0.value)" }.joined(separator: "; ")
                    result += indentation + "  group type: \(groupType.name)"
                    if !attrsStr.isEmpty { result += " [\(attrsStr)]" }
                    result += ";\n"
                }
                for check in qualityChecks {
                    result += indentation + "  qualityCheck: \(check);\n"
                }
                for transform in transforms {
                    result += indentation + "  transform: \(transform);\n"
                }
                result += indentation + "}\n"
            }

            return result
        }

        return generateNode(ast)
    }
}
