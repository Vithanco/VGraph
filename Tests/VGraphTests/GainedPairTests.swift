import Testing

@testable import VGraph

/// The pairs an edge type holds once detailings widen it (ADR-0032).
@Suite("Gained pairs")
struct GainedPairTests {
    static let person = NodeType(string: "Person")
    static let system = NodeType(string: "System")
    static let container = NodeType(string: "Container")
    static let database = NodeType(string: "Database")
    static let component = NodeType(string: "Component")

    static let uses = EdgeType(id: "uses", from: person, to: system)

    static let content = NotationContent(
        nodeTypes: [person, system, container, database, component],
        edgeTypes: [uses],
        detailings: [
            Detailing(nodeType: system, detailTypes: [container, database]),
            Detailing(nodeType: container, detailTypes: [component]),
        ])

    func installed(_ content: NotationContent = Self.content) throws(VError) -> VGraph {
        try VGraph().defineStandardAttributes().placing(content, in: .builtin)
    }

    func pair(_ from: NodeType, _ to: NodeType) -> NodeTypePair { NodeTypePair(from: from, to: to) }

    @Test("Given a relationship to a detailed type, then it also holds to every detail type at any depth")
    func oneEndReplacedAtAnyDepth() throws(VError) {
        let graph = try installed()
        #expect(
            graph.pairs(of: Self.uses) == [
                pair(Self.person, Self.system), pair(Self.person, Self.container),
                pair(Self.person, Self.database), pair(Self.person, Self.component),
            ])
    }

    @Test("Given a relationship between detailed types, then a pair with both ends replaced is not gained")
    func neverBothEnds() throws(VError) {
        var content = Self.content
        let talks = EdgeType(id: "talks", from: Self.system, to: Self.system)
        content.edgeTypes.append(talks)
        let pairs = try installed(content).pairs(of: talks)
        #expect(pairs.contains(pair(Self.container, Self.system)))
        #expect(pairs.contains(pair(Self.system, Self.component)))
        #expect(!pairs.contains(pair(Self.container, Self.container)))
        #expect(!pairs.contains(pair(Self.container, Self.component)))
    }

    @Test("Given a pair some type declares, then no other type gains it")
    func aDeclaredPairIsNotAlsoGained() throws(VError) {
        var content = Self.content
        let delivers = EdgeType(id: "delivers", from: Self.system, to: Self.person)
        let notifies = EdgeType(id: "notifies", from: Self.container, to: Self.person)
        content.edgeTypes += [delivers, notifies]
        let graph = try installed(content)
        #expect(!graph.pairs(of: delivers).contains(pair(Self.container, Self.person)))
        #expect(graph.pairs(of: delivers).contains(pair(Self.database, Self.person)))
        #expect(graph.edgeTypes(holdingFrom: Self.container, to: Self.person) == [notifies])
    }

    @Test("Given two types gaining the same undeclared pair, then both hold it")
    func aPairGainedTwiceIsAmbiguous() throws(VError) {
        var content = Self.content
        let delivers = EdgeType(id: "delivers", from: Self.system, to: Self.person)
        let notifies = EdgeType(id: "notifies", from: Self.container, to: Self.person)
        content.edgeTypes += [delivers, notifies]
        #expect(try installed(content).edgeTypes(holdingFrom: Self.component, to: Self.person) == [delivers, notifies])
    }

    @Test("Given a gained pair, then the graph answers the type that holds it")
    func theGraphAnswersWhichTypesHoldAPair() throws(VError) {
        let graph = try installed()
        #expect(graph.edgeTypes(holdingFrom: Self.person, to: Self.component) == [Self.uses])
        #expect(graph.edgeTypes(holdingFrom: Self.component, to: Self.person) == [])
    }

    @Test("Given a later layer adding a detailing, when it installs, then the new pairs are gained")
    func gainedPairsFollowEachInstall() throws(VError) {
        let flat = NotationContent(nodeTypes: Self.content.nodeTypes, edgeTypes: [Self.uses])
        let before = try installed(flat)
        #expect(before.pairs(of: Self.uses) == [pair(Self.person, Self.system)])

        let after = try before.placing(
            NotationContent(detailings: [Detailing(nodeType: Self.system, detailTypes: [Self.database])]),
            in: .vnotation)
        #expect(after.pairs(of: Self.uses) == [pair(Self.person, Self.system), pair(Self.person, Self.database)])
    }

    @Test("Given CLD, then same and opposite both hold Stock to Stock and nothing more")
    func cldStaysAmbiguous() throws(VError) {
        let cld = Notations.CausalLoopDiagram.self
        let graph = try cld.addNotation(addTo: VGraph().defineStandardAttributes())
        let stock = cld.NodeTypes.stock
        #expect(graph.edgeTypes(holdingFrom: stock, to: stock).map { $0.id } == [cld.EdgeTypes.same.id, cld.EdgeTypes.opposite.id])
        #expect(graph.edgeTypes.allSatisfy { graph.pairs(of: $0).count == 1 })
    }
}
