//
//  VAmbiguousEdge.swift
//  VGraph
//
//  What retyping a node leaves undecided about the edges around it.
//

/// One edge whose type stops being determined when its node is retyped, with
/// what it could become.
///
/// `changeType` is the only command that still holds a conversation: after the
/// new type is chosen it asks once per ambiguous edge, and *how many* depends on
/// the type just picked. An adapter driving it by name needs to know the
/// questions in advance, which is what this answers.
public struct VAmbiguousEdge: Sendable, Equatable {
    public let edgeId: String
    /// How to name the edge to the user — "A → B", by label where there is one.
    public let prompt: String
    public let options: [EdgeType]

    public init(edgeId: String, prompt: String, options: [EdgeType]) {
        self.edgeId = edgeId
        self.prompt = prompt
        self.options = options
    }
}

extension VGraph {
    /// Retype a node and re-seat every edge around it.
    ///
    /// `edgeTypes` answers `ambiguousEdges(ifRetyping:to:)` positionally — one per
    /// ambiguous edge, in the same order. An edge the new type determines on its
    /// own needs no answer, and one the notation has no type for at all gets an
    /// unknown one, which is how a [[Notation break]] stays visible.
    public func retyping(
        _ node: Node, to newType: NodeType, edgeTypes: [EdgeType.Id]
    ) throws(VError) -> VGraph {
        var result = self
        var retyped: [(edge: Edge.Id, type: EdgeType)] = []
        var cursor = 0

        for edge in try GraphExportOrderPreservation.sortByItemOrder(edges(at: node), in: self) {
            let options = edgeTypeOptions(for: edge, at: node, as: newType)

            if options.count > 1 {
                // Short of answers, or an answer naming no option: refuse rather
                // than guess which edge the user meant. Returning `self` here
                // retyped nothing and said nothing, which is the shrug the named
                // commands exist to remove.
                guard cursor < edgeTypes.count else {
                    throw VError.commandAnswersMismatched(.changeType, target: node.id)
                }
                let picked = edgeTypes[cursor]
                cursor += 1

                guard let chosen = options.named(picked) else {
                    throw VError.commandOptionNotOffered(
                        .changeType, target: node.id, option: picked.id)
                }
                retyped.append((edge.id, chosen))
            } else if let only = options.first {
                retyped.append((edge.id, only))
            } else {
                // An endpoint with no node type at all — a broken graph rather
                // than a bad argument, but still not something to swallow.
                guard let fromType = endType(edge.from, at: node, as: newType) else {
                    throw VError.nodeWithoutNodeType(edge.from)
                }
                guard let toType = endType(edge.to, at: node, as: newType) else {
                    throw VError.nodeWithoutNodeType(edge.to)
                }
                let unknown: EdgeType
                (result, unknown) = try result.ensureUnknownEdgeType(from: fromType, to: toType)
                retyped.append((edge.id, unknown))
            }
        }

        // A leftover means the caller's answers came from a different question
        // list than the one just walked.
        guard cursor == edgeTypes.count else {
            throw VError.commandAnswersMismatched(.changeType, target: node.id)
        }

        return try result.retype(node: node, to: newType, edgeTypes: retyped)
    }

    /// The edges that become ambiguous when `node` becomes `type`, **in the
    /// order the change consumes the answers** — the caller's array is
    /// positional, so this order is part of the contract rather than a detail.
    ///
    /// Empty in the common case: retyping usually leaves every edge with exactly
    /// one possible type, and then there is nothing to ask.
    public func ambiguousEdges(ifRetyping node: Node, to type: NodeType) -> [VAmbiguousEdge] {
        guard let ordered = try? GraphExportOrderPreservation.sortByItemOrder(edges(at: node), in: self)
        else { return [] }

        var result: [VAmbiguousEdge] = []
        for edge in ordered {
            let options = edgeTypeOptions(for: edge, at: node, as: type)
            if options.count > 1 {
                result.append(
                    VAmbiguousEdge(edgeId: edge.id.id, prompt: endsOf(edge), options: options))
            }
        }
        return result
    }
}

extension VGraph {
    /// How to name an edge to the user — "A → B", by label where there is one.
    func endsOf(_ edge: Edge) -> String {
        "\(name(of: edge.from)) → \(name(of: edge.to))"
    }

    func name(of node: Node) -> String {
        guard let label = label(of: .node(node)), !label.isEmpty else { return node.id }
        return label
    }
}
