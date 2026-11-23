import Testing

@testable import VGraph

struct DeclareTests {

    private func conceptMap() throws -> VGraph {
        try Notations.ConceptMap.addNotation(to: VGraph())
    }

    @Test func aVGLIdentifierCanBeDeclared() throws {
        #expect(try conceptMap().canDeclare(edgeTypeNamed: "_causes.directly-2"))
    }

    @Test func aNameTheParserWouldNotReadBackIsRefused() throws {
        let graph = try conceptMap()

        #expect(!graph.canDeclare(edgeTypeNamed: ""))
        #expect(!graph.canDeclare(edgeTypeNamed: "2causes"))
        #expect(!graph.canDeclare(edgeTypeNamed: "causes directly"))
        #expect(!graph.canDeclare(edgeTypeNamed: "edge"))
    }

    /// The lexer reads ASCII letters and digits only, so a non-ASCII letter
    /// would declare a type the reopened document cannot name.
    @Test func aNonASCIILetterIsRefused() throws {
        let graph = try conceptMap()

        #expect(!graph.canDeclare(edgeTypeNamed: "größer"))
        #expect(!graph.canDeclare(edgeTypeNamed: "élève"))
        #expect(!graph.canDeclare(edgeTypeNamed: "step٣"))
    }

    @Test func aTypeTheGraphAlreadyHasIsRefused() throws {
        let graph = try conceptMap()
        let existing = Notations.ConceptMap.EdgeTypes.conceptToRelation.id.id

        #expect(!graph.canDeclare(edgeTypeNamed: existing))
    }
}
