public enum VError: Error & Equatable & Sendable {
    case conversionError(from: String, to: String)
    case stringToEnumFailure(attributeValue: String, attributeType: String)
    case groupNotFound(Group)
    case nodeAlreadyInGroup(group: Group, node: Node)
    case subgraphAlreadyInGroup(group: Group, childGroup: Group)
    case nodeNotFound(Node)
    case edgeTypeNotFound(EdgeType.Id)
    case nodeTypeNotFound(NodeType)
    case edgeNotFound(Edge.Id)
    case nodeTypeStillInUse(NodeType)
    case nodeWithoutNodeType(Node)
    case edgeTypeStillInUse(Edge.Id)
    case edgeWithoutEdgeType(Edge.Id)
    case nodeAlreadyExists(Node)
    case nodeTypeAlreadyExists(NodeType)
    case edgeTypeAlreadyExists(EdgeType.Id)
    case edgeAlreadyExists(Edge.Id)
    case nodeTypeNotFoundForNode(Node)
    case edgeTypeNotFoundForEdge(Edge.Id)
    case attributeNotFound(Attribute.Id)
    case definitionAlreadyExists(Attribute.Id)
    case unknownItem(String)
    case invalidHexString(String)
    case EdgeTypeWrong(EdgeType.Id, from: NodeType, to: NodeType)
    case parsingError(String)
    case other(String)
    case wrongTarget(is: AttributeTarget, insteadOf: AttributeTarget)
    case notImplemented(String)
    case externalError(String)
    case attributeTypeNotComparable(String)
    case idCollision(id: String)
    case edgeEndpointIsGroup(edge: Edge.Id, endpoint: Group)
    case pipelineContractViolated(step: String, missing: [String])
    case documentExportOfTransformedGraph(steps: [String])
    /// A named command was asked to run where it does not apply, is disabled, or
    /// the notation forbids it and the break was not permitted.
    case commandUnavailable(VCommandID, target: String)
    /// The answers a named command was given do not match the questions the
    /// domain asked: none where one was required, too few, or more than were
    /// asked for.
    ///
    /// A **precondition**, not a request. Nothing resumes — the caller was
    /// supposed to ask first (`reverseCandidates`, `connectCandidates`,
    /// `ambiguousEdges(ifRetyping:to:)`) and call once with the answers. It was
    /// once `commandNeedsMoreInput`, which described the replay loop ADR-0013
    /// deleted: there is no second turn to supply anything on.
    case commandAnswersMismatched(VCommandID, target: String)
    /// A named command was answered with an option it never offered — a stale
    /// candidate list, or an id the caller invented. The type system cannot
    /// catch it: every candidate is an `EdgeType.Id`, and only the domain knows
    /// which ones apply here.
    case commandOptionNotOffered(VCommandID, target: String, option: String)
    /// `setURL` was given text `VURL` will not accept as a link. Its own case
    /// rather than one of the three above: nothing is missing and nothing is
    /// unavailable — the argument arrived and was rejected — and an adapter
    /// wants to tell it apart, since re-asking is right here and wrong for a
    /// target that has gone.
    case urlRefused(target: String, url: String)

    /// The same shape as `urlRefused`, and for the same reason: the name
    /// arrived and was rejected, so re-asking is right. A relationship's name
    /// has to be a VGL identifier the parser will read back, and it has to be
    /// one this graph does not already use.
    case edgeTypeNameRefused(name: String)

    case unknownAttributeLayer(AttributeLayer)
    case duplicateAttributeLayer(AttributeLayer)
    case duplicateView(String)
    case unknownView(String, available: [String])
    /// The label cannot give a view a name (empty, odd characters, a leading digit, a keyword); re-asking is right.
    case viewLabelRefused(label: String)
    /// The default view is the model: it has no layer to rename, duplicate or delete.
    case defaultViewIsFixed
    /// The layer's admission, or a diagram-only attribute off the root.
    case attributeNotAdmitted(Attribute.Id, key: ItemKey, layer: AttributeLayer)
    case attributeTypeMismatch(Attribute.Id, expected: String, found: String)
    /// Notation errors, reported when the notation installs (ADR-0032).
    case detailingNamesUnknownType(of: NodeType, unknown: NodeType)
    /// The types around the cycle, the first repeated at the end.
    case detailingCycle([NodeType])
    /// `group x: Name` would not say whether x is a detailed node or a plain group.
    case typeNameIsNodeAndGroupType(String)
}

extension VError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .unknownAttributeLayer(let layer):
            return "Unknown attribute layer '\(layer.rawValue)'"
        case .duplicateAttributeLayer(let layer):
            return "Attribute layer '\(layer.rawValue)' already exists"
        case .duplicateView(let name):
            return "View '\(name)' is declared twice"
        case .unknownView(let name, let available):
            let known = available.isEmpty ? "it declares none" : "it has: \(available.joined(separator: ", "))"
            return "The document has no view '\(name)'; \(known)"
        case .viewLabelRefused(let label):
            return "Not a label a view can be named from: '\(label)'"
        case .defaultViewIsFixed:
            return "The default view cannot be renamed, duplicated or deleted"
        case .attributeNotAdmitted(let id, let key, let layer):
            return "Layer '\(layer.rawValue)' does not admit '\(id.description)' on \(key.description)"
        case .attributeTypeMismatch(let id, let expected, let found):
            return "Attribute '\(id.description)' is a \(expected), not a \(found)"
        case .detailingNamesUnknownType(let nodeType, let unknown):
            return "'\(nodeType.id)' is detailed by '\(unknown.id)', which is not a node type"
        case .detailingCycle(let types):
            return "Detailings form a cycle: \(types.map { $0.id }.joined(separator: " → "))"
        case .typeNameIsNodeAndGroupType(let name):
            return "'\(name)' is both a node type and a group type"
        case .commandUnavailable(let id, let target):
            return "Command '\(id.raw)' is not available on '\(target)'"
        case .commandAnswersMismatched(let id, let target):
            return "Command '\(id.raw)' on '\(target)' was not given the answers it asked for"
        case .commandOptionNotOffered(let id, let target, let option):
            return "Command '\(id.raw)' on '\(target)' does not offer the option '\(option)'"
        case .urlRefused(let target, let url):
            return "Not a link that may be stored on '\(target)': '\(url)'"
        case .edgeTypeNameRefused(let name):
            return "Not a name a relationship may take: '\(name)'"
        case .conversionError(let from, let to):
            return "Conversion error: cannot convert '\(from)' to '\(to)'"
        case .stringToEnumFailure(let value, let type):
            return "String to enum failure: '\(value)' is not a valid \(type)"
        case .groupNotFound(let group):
            return "Group not found: \(group.id.id)"
        case .nodeAlreadyInGroup(let group, let node):
            return "Node '\(node.id)' already in group '\(group.id.id)'"
        case .subgraphAlreadyInGroup(let group, let childGroup):
            return "Subgraph '\(childGroup.id.id)' already in group '\(group.id.id)'"
        case .nodeNotFound(let node):
            return "Node not found: \(node.id)"
        case .edgeTypeNotFound(let edgeType):
            return "Edge type not found: \(edgeType.id)"
        case .nodeTypeNotFound(let nodeType):
            return "Node type not found: \(nodeType.id)"
        case .edgeNotFound(let edge):
            return "Edge not found: \(edge.id)"
        case .nodeTypeStillInUse(let nodeType):
            return "Node type still in use: \(nodeType.id)"
        case .nodeWithoutNodeType(let node):
            return "Node without node type: \(node.id)"
        case .edgeTypeStillInUse(let edge):
            return "Edge type still in use: \(edge.id)"
        case .edgeWithoutEdgeType(let edge):
            return "Edge without edge type: \(edge.id)"
        case .nodeAlreadyExists(let node):
            return "Node already exists: \(node.id)"
        case .nodeTypeAlreadyExists(let nodeType):
            return "Node type already exists: \(nodeType.id)"
        case .edgeTypeAlreadyExists(let edgeType):
            return "Edge type already exists: \(edgeType.id)"
        case .edgeAlreadyExists(let edge):
            return "Edge already exists: \(edge.id)"
        case .nodeTypeNotFoundForNode(let node):
            return "Node type not found for node: \(node.id)"
        case .edgeTypeNotFoundForEdge(let edge):
            return "Edge type not found for edge: \(edge.id)"
        case .attributeNotFound(let attr):
            return "Attribute not found: \(attr.id)"
        case .definitionAlreadyExists(let attr):
            return "Definition already exists: \(attr.id)"
        case .unknownItem(let item):
            return "Unknown item: \(item)"
        case .invalidHexString(let hex):
            return "Invalid hex string: \(hex)"
        case .EdgeTypeWrong(let edgeType, let from, let to):
            return "Edge type '\(edgeType.id)' wrong for nodes from '\(from.id)' to '\(to.id)'"
        case .parsingError(let msg):
            return "Parsing error: \(msg)"
        case .other(let msg):
            return "Error: \(msg)"
        case .wrongTarget(let actual, let expected):
            return "Wrong target: is \(actual), expected \(expected)"
        case .notImplemented(let feature):
            return "Not implemented: \(feature)"
        case .externalError(let msg):
            return "External error: \(msg)"
        case .attributeTypeNotComparable(let type):
            return "Attribute type not comparable: \(type)"
        case .idCollision(let id):
            return
                "ID collision: '\(id)' is already used by a different kind of entity (node/nodeType/edge/edgeType/group share an attribute keyspace)"
        case .edgeEndpointIsGroup(let edge, let endpoint):
            return "Edge '\(edge.id)' cannot have a group as endpoint: '\(endpoint.id.id)' is a group"
        case .pipelineContractViolated(let step, let missing):
            return "Pipeline contract violated: step '\(step)' requires \(missing.joined(separator: ", ")) to have run first"
        case .documentExportOfTransformedGraph(let steps):
            return
                "Document export of a transformed graph: \(steps.joined(separator: ", ")) already ran. VGL is serialised from the OriginGraph, never from pipeline output"
        }
    }
}
