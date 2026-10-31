import Testing

@testable import VGraph

/// A built-in notation that is hierarchical, so detailings can be tested before
/// any shipped notation declares one.
enum Hierarchy: NotationDeclaration {
    static let id: Identifier<Notation> = .init(rawValue: "Hierarchy")

    static let system = NodeType(string: "System")
    static let container = NodeType(string: "Container")
    static let database = NodeType(string: "Database")
    static let process = NodeType(string: "Process")

    struct NodeTypes: NotationNodeTypes {
        static var all: [NodeType] { [system, container, database, process] }
        static var allDefinitions: [NodeTypeDefinition] {
            [
                NodeTypeDefinition(system, description: "", detailedBy: [container, database]),
                NodeTypeDefinition(container, description: ""),
                NodeTypeDefinition(database, description: ""),
                NodeTypeDefinition(process, description: "", detailedBy: [process]),
            ]
        }
    }

    struct EdgeTypes: NotationEdgeTypes {
        static var all: [EdgeType] { [] }
    }
}

@Suite("Detailings")
struct DetailingTests {
    func blank() throws(VError) -> VGraph { try VGraph().defineStandardAttributes() }

    @Test("Given a built-in notation that declares detailings, when it installs, then the graph answers them")
    func aBuiltInNotationDeclaresDetailings() throws(VError) {
        let graph = try blank().placing(Hierarchy.content, in: .builtin)
        #expect(graph.detailTypes(of: Hierarchy.system) == [Hierarchy.container, Hierarchy.database])
        #expect(graph.detailTypes(of: Hierarchy.container) == [])
    }

    @Test("Given a type detailed by itself, when the notation installs, then it is accepted")
    func aTypeMayDetailItself() throws(VError) {
        let graph = try blank().placing(Hierarchy.content, in: .builtin)
        #expect(graph.detailTypes(of: Hierarchy.process) == [Hierarchy.process])
    }

    @Test("Given a detailing that names an undeclared type, when the notation installs, then it is refused")
    func aDetailingMustNameDeclaredTypes() throws(VError) {
        let typo = NodeType(string: "Contianer")
        let content = NotationContent(
            nodeTypes: [Hierarchy.system], detailings: [Detailing(nodeType: Hierarchy.system, detailTypes: [typo])])
        #expect(throws: VError.detailingNamesUnknownType(of: Hierarchy.system, unknown: typo)) {
            try blank().placing(content, in: .builtin)
        }
    }

    @Test("Given two types that detail each other, when the notation installs, then the cycle is refused")
    func detailingsNeverFormACycle() throws(VError) {
        let a = NodeType(string: "A")
        let b = NodeType(string: "B")
        let c = NodeType(string: "C")
        let content = NotationContent(
            nodeTypes: [a, b, c],
            detailings: [
                Detailing(nodeType: a, detailTypes: [b]), Detailing(nodeType: b, detailTypes: [c]),
                Detailing(nodeType: c, detailTypes: [a]),
            ])
        #expect(throws: VError.detailingCycle([a, b, c, a])) {
            try blank().placing(content, in: .builtin)
        }
    }

    @Test("Given a name that is both a node type and a group type, when the notation installs, then it is refused")
    func noNameIsBothANodeTypeAndAGroupType() throws(VError) {
        let graph = try blank().placing(Hierarchy.content, in: .builtin)
        let clash = NotationContent(groupTypes: [GroupType(string: "Container")])
        #expect(throws: VError.typeNameIsNodeAndGroupType("Container")) {
            try graph.placing(clash, in: .builtin)
        }
    }

    func vnotation(detailing nodeType: NodeType, by detailTypes: [NodeType]) -> DynamicNotation {
        DynamicNotation(
            id: .init(rawValue: "Mine"),
            nodeTypeSpecs: [
                NodeTypeSpec(name: nodeType.id, nodeStyle: nil, rawAttrs: [:], detailedBy: detailTypes.map { $0.id })
            ],
            edgeTypeSpecs: [], graphAttrs: [], baseEntry: Hierarchy.entry)
    }

    @Test("Given a vnotation extending a built-in, when it adds a detailing, then the graph answers the union")
    func aVnotationAddsToTheBuiltInDetailings() throws(VError) {
        let graph = try vnotation(detailing: Hierarchy.system, by: [Hierarchy.process]).addNotation(addTo: blank())
        #expect(graph.detailTypes(of: Hierarchy.system) == [Hierarchy.container, Hierarchy.database, Hierarchy.process])
        #expect(graph.detailTypes(of: Hierarchy.system, declaredIn: .vnotation) == [Hierarchy.process])
    }

    @Test("Given a vnotation restating an inherited detailing, when it installs, then the detailing stays the base's")
    func aRestatedDetailingIsNotTheVnotations() throws(VError) {
        let graph = try vnotation(detailing: Hierarchy.system, by: [Hierarchy.database]).addNotation(addTo: blank())
        #expect(graph.detailTypes(of: Hierarchy.system) == [Hierarchy.container, Hierarchy.database])
        #expect(graph.detailTypes(of: Hierarchy.system, declaredIn: .vnotation) == [])
    }

    @Test("Given a vnotation whose detailing closes a cycle with its base's, when it installs, then it is refused")
    func aCycleClosedByAVnotationIsRefused() throws(VError) {
        let notation = vnotation(detailing: Hierarchy.container, by: [Hierarchy.system])
        #expect(throws: VError.detailingCycle([Hierarchy.system, Hierarchy.container, Hierarchy.system])) {
            try notation.addNotation(addTo: blank())
        }
    }

    @Test("Given a notation without detailings, when it installs, then no type has detail types")
    func aFlatNotationHasNoDetailings() throws(VError) {
        let graph = try blank().placing(Notations.Ibis.content, in: .builtin)
        #expect(graph.nodeTypes.allSatisfy { graph.detailTypes(of: $0).isEmpty })
    }
}
