import VGraph

/// The comments attached to one declaration. See ADR-0010 for the encoding.
public struct Comments: Sendable {
    public let leading: String?
    public let trailing: String?

    public init(leading: String?, trailing: String?) {
        self.leading = leading
        self.trailing = trailing
    }
}

public struct VNotationNodeTypeDecl {
    public let name: String
    public let attrs: [(key: String, value: String)]
    public let detailedBy: [String]
}

public struct VNotationGroupTypeDecl {
    public let name: String
    public let attrs: [(key: String, value: String)]
}

public struct VNotationEdgeTypeDecl {
    public let id: String
    public let from: String
    public let to: String
    public let attrs: [(key: String, value: String)]
}

/// Already validated: the parser refuses anything `IconArtwork.make` will not
/// accept, so the AST never carries artwork a renderer would choke on.
public struct VNotationIconDecl {
    public let name: String
    public let artwork: IconArtwork
}

/// Only names are kept: whether they exist is no concern of a view.
public struct VViewStatementDecl {
    public enum Target { case node, group }

    public let target: Target
    public let isType: Bool
    public let names: [String]
    public let attrs: [(key: String, value: String)]
}

public struct VViewDecl {
    public let name: String
    public let label: String?
    public let attrs: [(key: String, value: String)]
    public let statements: [VViewStatementDecl]
    public let rules: [ViewRule]
}

public indirect enum ASTNode {
    case file(vnotations: [ASTNode], document: ASTNode, views: [VViewDecl])
    case vnotationDecl(
        name: String,
        extendsNotation: String?,
        graphAttrs: [(key: String, value: String)],
        nodeTypes: [VNotationNodeTypeDecl],
        edgeTypes: [VNotationEdgeTypeDecl],
        groupTypes: [VNotationGroupTypeDecl],
        icons: [VNotationIconDecl],
        qualityChecks: [String],
        transforms: [String]
    )
    case document(
        id: String, type: String, extensions: [String], label: String?, children: [ASTNode], comments: Comments)
    /// A `metagraph` declaration that renders the structure of a notation itself as a diagram.
    case metagraph(notationName: String, label: String?)
    /// A `metadescription` declaration that emits a self-describing Markdown document for a
    /// notation, *plus* the same structural metagraph so both views ship together.
    case metadescription(notationName: String, label: String?)
    case group(id: String, type: String?, label: String?, isFolded: Bool, children: [ASTNode], comments: Comments)
    case node(id: String, type: String, label: String?, attributes: [ASTNode], comments: Comments)
    case edge(fromId: String, toId: String, type: String?, label: String?, attributes: [ASTNode], comments: Comments)
    case attribute(id: String, value: String)

    func findNodes(where predicate: (ASTNode) -> Bool) -> [ASTNode] {
        var result: [ASTNode] = []

        if predicate(self) {
            result.append(self)
        }

        for child in children() {
            result.append(contentsOf: child.findNodes(where: predicate))
        }

        return result
    }

    func findFirstNode(where predicate: (ASTNode) -> Bool) -> ASTNode? {
        if predicate(self) {
            return self
        }

        for child in children() {
            if let found = child.findFirstNode(where: predicate) {
                return found
            }
        }

        return nil
    }

    func children() -> [ASTNode] {
        switch self {
        case .file(let vnotations, let document, _):
            return vnotations + [document]
        case .document(_, _, _, _, let children, _),
            .group(_, _, _, _, let children, _):
            return children
        case .node(_, _, _, let attributes, _),
            .edge(_, _, _, _, let attributes, _):
            return attributes
        case .attribute, .vnotationDecl, .metagraph, .metadescription:
            return []
        }
    }

    func prettyPrint(indent: Int = 0) -> String {
        let indentation = String(repeating: "  ", count: indent)
        var result = indentation

        switch self {
        case .file:
            result += "File"
        case .vnotationDecl(let name, let extendsNotation, _, _, _, _, _, _, _):
            result += "VNotation \(name)"
            if let ext = extendsNotation { result += " extends \(ext)" }
        case .document(let id, let type, let extensions, let label, _, _):
            let typeDecl = ([type] + extensions).joined(separator: ", ")
            result += "Document \(id) : \(typeDecl)"
            if let label = label, !label.isEmpty {
                result += " \"\(label)\""
            }
        case .metagraph(let notationName, let label):
            result += "Metagraph \(notationName)"
            if let label = label, !label.isEmpty {
                result += " \"\(label)\""
            }
        case .metadescription(let notationName, let label):
            result += "Metadescription \(notationName)"
            if let label = label, !label.isEmpty {
                result += " \"\(label)\""
            }
        case .group(let id, let type, let label, let isFolded, _, _):
            if isFolded {
                result += "Folded Group \(id)"
            } else {
                result += "Group \(id)"
            }
            if let type = type, !type.isEmpty {
                result += " : \(type)"
            }
            if let label = label, !label.isEmpty {
                result += " \"\(label)\""
            }
        case .node(let id, let type, let label, _, _):
            result += "Node \(id) : \(type)"
            if let label = label, !label.isEmpty {
                result += " \"\(label)\""
            }
        case .edge(let sourceId, let targetId, let type, let label, _, _):
            result += "Edge \(sourceId) -> \(targetId)"
            if let type = type, !type.isEmpty {
                result += " : \(type)"
            }
            if let label = label, !label.isEmpty {
                result += " \"\(label)\""
            }
        case .attribute(let id, let value):
            result += "Attribute \(id) : \(value)"
        }

        let children = self.children()
        if !children.isEmpty {
            result += " {\n"
            for child in children {
                result += child.prettyPrint(indent: indent + 1) + "\n"
            }
            result += indentation + "}"
        }

        return result
    }
}
