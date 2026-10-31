public protocol NotationNodeTypes {
    static var all: [NodeType] { get }
    static var allDefinitions: [NodeTypeDefinition] { get }
}

extension NotationNodeTypes {
    public static var allDefinitions: [NodeTypeDefinition] {
        all.map { NodeTypeDefinition($0, description: "") }
    }
}

public protocol NotationGroupTypes {
    static var all: [GroupType] { get }
    static var allDefinitions: [GroupTypeDefinition] { get }
}

extension NotationGroupTypes {
    public static var allDefinitions: [GroupTypeDefinition] {
        all.map { GroupTypeDefinition($0, description: "") }
    }
}

/// The associated type's default, so the notations with no boundaries — all of
/// them but C4 — do not have to say "none".
public struct NoGroupTypes: NotationGroupTypes {
    public static var all: [GroupType] { [] }
}

public protocol NotationEdgeTypes {
    static var all: [EdgeType] { get }
    static var allDefinitions: [EdgeTypeDefinition] { get }
}

extension NotationEdgeTypes {
    public static var allDefinitions: [EdgeTypeDefinition] {
        all.map { EdgeTypeDefinition($0, description: "") }
    }
}

public protocol AddNotationBase {
    associatedtype NodeTypes: NotationNodeTypes
    associatedtype EdgeTypes: NotationEdgeTypes
    associatedtype GroupTypes: NotationGroupTypes = NoGroupTypes

    /// A step rather than a bare transform, so it records itself in `completedSteps`.
    static var step: TransformStep? { get }

    static var qualityChecks: [QualityCheck] { get }

    /// Attributes the notation brings beyond VGraph's own.
    static var definitions: AttributeDefContainer { get }

    /// The values on the notation's types, as data. Its types come from
    /// `NodeTypes`, `EdgeTypes` and `GroupTypes`.
    static var values: [TypeValues] { get }
}

extension AddNotationBase {
    /// On `AddNotationBase` rather than `NotationDeclaration` so extensions inherit it too.
    public static var step: TransformStep? { nil }

    public static var definitions: AttributeDefContainer { [:] }

    public static var values: [TypeValues] { [] }
}

public struct Notation: VProtocol, UseIdentifier {
    public let id: Identifier<Notation>

    public init(rawValue: String) {
        id = Identifier(rawValue: rawValue)
    }

    public init(id: Identifier<Notation>) {
        self.id = id
    }
}

/// Populated from the "Further Information" section of the notation's website page.
public struct NotationReference: Sendable {
    public let title: String
    public let url: String?

    public init(title: String, url: String? = nil) {
        self.title = title
        self.url = url
    }
}

/// The registry's unified entry for both compiled notations and runtime `vnotation`
/// ones. A value type with closures rather than `any NotationDeclaration.Type`, because
/// Embedded Swift rejected stored metatypes before 6.4 — not a pattern to copy (AGENTS.md).
public struct NotationEntry: @unchecked Sendable {
    public let id: Identifier<Notation>
    public let notation: Notation
    public let diagramLogic: DiagramLogic
    public let description: String
    public let purpose: String
    public let whenToUse: [String]
    public let history: String
    public let references: [NotationReference]
    /// Empty for dynamic notations.
    public let nodeTypeDefinitions: [NodeTypeDefinition]
    /// Empty for dynamic notations.
    public let edgeTypeDefinitions: [EdgeTypeDefinition]
    /// Empty for dynamic notations, and for every notation without boundaries.
    public let groupTypeDefinitions: [GroupTypeDefinition]
    public let content: NotationContent
    public let step: TransformStep?
    /// Pre-resolved from a `vnotation … extends …` clause, so the parser can stamp
    /// `Group.extendsNotation` without a runtime cast.
    public let baseId: Identifier<Notation>?
    /// Synthesised from a `vnotation` block rather than a compiled `NotationDeclaration`.
    /// Drives `metadescription`: dynamic notations carry no Markdown today (see VGraphParser.swift).
    public let isDynamic: Bool
    /// The [[Graph criterion]]s the notation declares by name.
    public let criteria: [QualityCheckSpec]
}

public struct ExtensionEntry: @unchecked Sendable {
    public let id: String
    public let nodeContent: NotationContent
    public let edgeContent: ([NodeType]) -> NotationContent
}

public protocol NotationDeclaration: AddNotationBase {
    static var id: Identifier<Notation> { get }
    static var notation: Notation { get }
    static var diagramLogic: DiagramLogic { get }

    // The self-description fields below are prose lifted from the notation's own
    // authoritative documentation, not written here; `metadescription` assembles
    // them into a Markdown document.
    static var description: String { get }
    static var purpose: String { get }
    static var whenToUse: [String] { get }
    static var history: String { get }
    static var references: [NotationReference] { get }

    /// Named, unlike `qualityChecks`, so a command can ask whether one is in force
    /// before it offers something the criterion would then report (ADR-0011).
    static var criteria: [QualityCheckSpec] { get }
}

extension NotationDeclaration {

    public static var entry: NotationEntry {
        NotationEntry(
            id: id,
            notation: notation,
            diagramLogic: diagramLogic,
            description: description,
            purpose: purpose,
            whenToUse: whenToUse,
            history: history,
            references: references,
            nodeTypeDefinitions: NodeTypes.allDefinitions,
            edgeTypeDefinitions: EdgeTypes.allDefinitions,
            groupTypeDefinitions: GroupTypes.allDefinitions,
            content: content,
            step: Self.step,
            baseId: nil,
            isDynamic: false,
            criteria: criteria
        )
    }

    public static var description: String { "" }

    // Empty defaults so a notation can adopt the self-description fields one at a
    // time (IBIS is the pilot) without every other notation having to.
    public static var purpose: String { "" }
    public static var whenToUse: [String] { [] }
    public static var history: String { "" }
    public static var references: [NotationReference] { [] }

    public static func renderMarkdown(displayTitle: String?) -> String {
        NotationMarkdown.render(entry: Self.entry, displayTitle: displayTitle)
    }

    public static var content: NotationContent {
        NotationContent(
            definitions: definitions, nodeTypes: NodeTypes.all, edgeTypes: EdgeTypes.all, groupTypes: GroupTypes.all,
            detailings: NodeTypes.allDefinitions.filter { !$0.detailedBy.isEmpty }.map {
                Detailing(nodeType: $0.nodeType, detailTypes: $0.detailedBy)
            },
            values: [.diagram([Attributes.Group.diagramLogic(diagramLogic)])] + values)
    }

    public static var notation: Notation {
        return Notation(id: id)
    }

    public static var diagramLogic: DiagramLogic { .noLogic }

    public static var qualityChecks: [QualityCheck] { [] }

    public static var criteria: [QualityCheckSpec] { [] }
}

/// Supplements an existing notation for infrastructure purposes (group folding,
/// rendering) rather than defining a graph's primary domain vocabulary.
///
/// Registration is two-phase so that extensions applied together each see all node
/// types from all extensions before any of them generates edge types.
public protocol NotationExtension: AddNotationBase {
    static var nodeContent: NotationContent { get }
    /// `nodeTypes` are every node type in the graph, the other extensions' included.
    static func edgeContent(given nodeTypes: [NodeType]) -> NotationContent
}

extension NotationExtension {

    public static var nodeContent: NotationContent {
        NotationContent(definitions: definitions, nodeTypes: NodeTypes.all, values: values)
    }

    public static func edgeContent(given nodeTypes: [NodeType]) -> NotationContent {
        NotationContent(edgeTypes: EdgeTypes.all)
    }

    public static var qualityChecks: [QualityCheck] { [] }
}

extension NotationExtension {
    public static func extensionEntry(id: String) -> ExtensionEntry {
        ExtensionEntry(
            id: id,
            nodeContent: nodeContent,
            edgeContent: Self.edgeContent(given:)
        )
    }
}

public enum Notations {}

extension Notations {

    public static func notationStep(for notationName: String) -> TransformStep? {
        NotationRegistry.entry(for: notationName)?.step
    }

    public static func resolveSteps(for graph: VGraph) throws(VError) -> [TransformStep] {
        let declared = graph.notationDefinition.declaredTransforms
        if !declared.isEmpty {
            var resolved: [TransformStep] = []
            for name in declared {
                if let step = try TransformRegistry.resolveStep(name: name) {
                    resolved.append(step)
                }
            }
            return resolved
        }
        if let step = notationStep(for: graph.notationName) { return [step] }
        return []
    }

    public static func resolveTransform(for graph: VGraph) throws(VError) -> GraphTransform {
        TransformStep.pipeline(try resolveSteps(for: graph))
    }

    /// Only the *phase* is named here; a notation's own step records itself in addition.
    /// The ledger is therefore a tree, so no step may declare `requires:` on a
    /// notation-internal id — it would hold for ConceptMap and throw for the rest.
    public static var notationTransformsStep: TransformStep {
        TransformStep(.notationTransforms) { (graph: VGraph) throws(VError) in
            try TransformStep.pipeline(try resolveSteps(for: graph))(graph)
        }
    }

    public static var extensionSteps: [TransformStep] {
        [notationTransformsStep, FoldGroups.foldStep, FoldGroups.bundleStep, boundaryChromeStep]
    }

    public static func notationQualityChecks(for notationName: String) -> [QualityCheck] {
        switch notationName {
        case "ConceptMap": return ConceptMap.qualityChecks
        case "IBIS": return Ibis.qualityChecks
        case "GoalTree": return GoalTree.qualityChecks
        case "C4": return C4.qualityChecks
        case "Arithmetic": return Arithmetic.qualityChecks
        case "CLD": return CausalLoopDiagram.qualityChecks
        default: return []
        }
    }

    public static var extensionQualityChecks: [QualityCheck] {
        FoldGroups.qualityChecks
    }

    /// The named criteria in force for `graph`: a `vnotation`'s own list when it
    /// declares one, the compiled notation's otherwise. Quality analysis and the
    /// commands both read this, so what is offered and what is reported agree.
    public static func criteria(of graph: VGraph) -> [QualityCheckSpec] {
        let declared = graph.notationDefinition.declaredQualityChecks
        if !declared.isEmpty { return declared }
        return NotationRegistry.entry(for: graph.notationName)?.criteria ?? []
    }

    public static func analyzeQuality(graph: VGraph) -> QualityReport {
        // A metagraph draws the notation's types, not a diagram made with it. The
        // criteria judge diagrams: Stock → Stock twice is two edge types, not a
        // parallel edge, and one Goal Tree node of each type is not one CSF.
        guard !graph.isMetagraph else {
            return QualityReport(notationName: graph.notationName, messages: [])
        }
        var messages: [MessageWithSeverity] = []

        messages.append(contentsOf: GenericQualityChecks.analyze(graph))

        let notationName = graph.notationName

        for spec in criteria(of: graph) {
            if let check = try? QualityCheckRegistry.resolve(spec) {
                messages.append(contentsOf: check(graph))
            }
        }
        if graph.notationDefinition.declaredQualityChecks.isEmpty {
            for check in notationQualityChecks(for: notationName) {
                messages.append(contentsOf: check(graph))
            }
        }

        for check in extensionQualityChecks {
            messages.append(contentsOf: check(graph))
        }

        return QualityReport(notationName: notationName, messages: messages)
    }
}

/// The single source of truth for built-in notation dispatch and for the
/// valid-notation error message: adding a notation means adding one entry here and
/// nothing anywhere else. Notations defined via `vnotation` live in
/// `VGraphParser.dynamicNotations` and are checked before this registry.
public enum NotationRegistry {

    public static let entries: [(id: String, entry: NotationEntry)] = [
        ("IBIS", Notations.Ibis.entry),
        ("BBS", Notations.Bbs.entry),
        ("ImpactMapping", Notations.ImpactMapping.entry),
        ("ConceptMap", Notations.ConceptMap.entry),
        ("CRT", Notations.CurrentRealityTree.entry),
        ("EC", Notations.EvaporatingCloud.entry),
        ("FRT", Notations.FutureRealityTree.entry),
        ("PRT", Notations.PrerequisiteTree.entry),
        ("TRT", Notations.TransitionTree.entry),
        ("ADTree", Notations.ADTree.entry),
        ("GoalTree", Notations.GoalTree.entry),
        ("CLD", Notations.CausalLoopDiagram.entry),
        ("DecisionTree", Notations.DecisionTree.entry),
        ("Timeline", Notations.Timeline.entry),
        ("C4", Notations.C4.entry),
        ("Arithmetic", Notations.Arithmetic.entry),
    ]

    /// The id is the VGL name users write after the notation (e.g. `: ConceptMap, Annotation`).
    public static let extensionEntries: [ExtensionEntry] = [
        Notations.Annotation.extensionEntry(id: "Annotation")
        // FoldGroups is applied unconditionally via `Notations.extensionSteps`,
        // not selected by name, so it is not included here.
    ]

    public static var validNames: String { entries.map { $0.id }.joined(separator: ", ") }

    public static func entry(for name: String) -> NotationEntry? {
        entries.first(where: { $0.id == name })?.entry
    }

    public static func extensionEntry(for name: String) -> ExtensionEntry? {
        extensionEntries.first(where: { $0.id == name })
    }
}

extension VGraph {
    /// Every node is a notation type, which is how `metagraph` names them.
    var isMetagraph: Bool {
        !nodes.isEmpty && nodes.allSatisfy { $0.description.hasPrefix("_meta_") }
    }
}
