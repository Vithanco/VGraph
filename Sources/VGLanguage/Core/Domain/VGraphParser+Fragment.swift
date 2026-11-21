import VGraph

extension VGraphParser {
    func parse(fragment source: String, into graph: VGraph, under group: Group?) throws(VError)
        -> (graph: VGraph, pasted: [String])
    {
        let elements = Set(graph.nodes.map { $0.id } + graph.groups.map { $0.id.id })
        let existing = elements.union(graph.edges.map { $0.id.id })
        let statements = try fragmentStatements(source, knownIds: elements)
        var declarations: [ASTNode] = []
        for statement in statements {
            declarations += statement.findNodes(where: { $0.declaredId != nil })
        }
        let unknown = Self.unknownTypes(among: declarations, of: graph)
        guard unknown.isEmpty else { throw VError.fragmentNamesUnknownTypes(unknown) }

        let renames = Self.renames(of: declarations.compactMap { $0.declaredId }, avoiding: existing)
        let renamed = statements.map { $0.renaming(renames) }
        let stack = ParserStack(currentGroup: group ?? Group(rawValue: rootGroup))
        var result = graph
        for statement in renamed {
            result = try convert(from: statement, graph: result, stack: stack)
        }
        return (result, renamed.compactMap { $0.declaredId })
    }

    /// The bare `catch`, as in `parseToAST`, keeps clear of a typed-throws SILGen crash.
    private func fragmentStatements(_ source: String, knownIds: Set<String>) throws(VError) -> [ASTNode] {
        let lexer = Lexer(source: source)
        let parser = Parser(tokens: lexer.scanTokens(), comments: lexer.comments, knownIds: knownIds)
        do {
            return try parser.fragment()
        } catch {
            throw VError.parsingError(error.description)
        }
    }

    /// Sorted, so the refusal reads the same however the fragment was ordered.
    private static func unknownTypes(among declarations: [ASTNode], of graph: VGraph) -> [String] {
        var unknown: Set<String> = []
        for declaration in declarations {
            switch declaration {
            case .node(_, let type, _, _, _) where !graph.has(nodeTypeName: type):
                unknown.insert(type)
            case .group(_, let type?, _, _, _, _)
            where !type.isEmpty && !graph.has(nodeTypeName: type) && !graph.has(groupTypeName: type):
                unknown.insert(type)
            default:
                continue
            }
        }
        return unknown.sorted()
    }

    private static func renames(of declared: [String], avoiding existing: Set<String>) -> [String: String] {
        var taken = existing.union(declared)
        var renames: [String: String] = [:]
        for id in declared where existing.contains(id) {
            let fresh = VGraph.freeId(near: id) { taken.contains($0) }
            taken.insert(fresh)
            renames[id] = fresh
        }
        return renames
    }
}

extension ASTNode {
    var declaredId: String? {
        switch self {
        case .node(let id, _, _, _, _), .group(let id, _, _, _, _, _): return id
        default: return nil
        }
    }

    func renaming(_ renames: [String: String]) -> ASTNode {
        guard !renames.isEmpty else { return self }
        func renamed(_ id: String) -> String { renames[id] ?? id }
        switch self {
        case .node(let id, let type, let label, let attributes, let comments):
            return .node(id: renamed(id), type: type, label: label, attributes: attributes, comments: comments)
        case .group(let id, let type, let label, let isFolded, let children, let comments):
            return .group(
                id: renamed(id), type: type, label: label, isFolded: isFolded,
                children: children.map { $0.renaming(renames) }, comments: comments)
        case .edge(let fromId, let toId, let type, let label, let attributes, let comments):
            return .edge(
                fromId: renamed(fromId), toId: renamed(toId), type: type, label: label, attributes: attributes,
                comments: comments)
        default:
            return self
        }
    }
}
