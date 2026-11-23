import Testing

@testable import VGraph

/// Which notation a graph is drawn in selects its notation layers, so it is
/// part of the notation definition rather than a value inside them (ADR-0030).
@Suite
struct NotationDefinitionTests {
    @Test("Given a graph built in code, when its notation is asked for, then it is IBIS")
    func aGraphDefaultsToIBIS() {
        #expect(VGraph().notationName == "IBIS")
    }

    @Test("Given a notation, what it extends and its extensions, when the root's attributes are read, then none is among them")
    func theNotationSelectorsAreNotAttributes() throws(VError) {
        let graph = VGraph()
            .using(notation: "MyNotation")
            .extending(notation: "IBIS")
            .using(extensions: ["FoldGroups"])
        #expect(try graph.graphAttributes().isEmpty)
        #expect(graph.notationName == "MyNotation")
        #expect(graph.notationDefinition.extends == "IBIS")
        #expect(graph.notationDefinition.extensions == ["FoldGroups"])
    }

    @Test("Given a group type already registered, when it is registered again, then it is listed once")
    func aGroupTypeIsRegisteredOnce() {
        let team = GroupType(rawValue: "Team")
        let definition = NotationDefinition().registering(team).registering(team)
        #expect(definition.groupTypes == [team])
    }
}
