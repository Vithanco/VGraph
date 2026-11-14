import Testing

@testable import VGraph

@Suite
struct DiagramLogicTests {

    @Test func testFromStringRoundTrips() throws {
        for logic in DiagramLogic.allCases {
            let roundTripped = try DiagramLogic.fromString(logic.readableName)
            #expect(roundTripped == logic)
        }
    }

    /// Read where `redundantJunctor` reads it: the diagram attribute a notation installs.
    @Test(arguments: [
        ("CRT", DiagramLogic.sufficientCause), ("FRT", .sufficientCause), ("TRT", .sufficientCause),
        ("ADTree", .sufficientCause),
        ("PRT", .necessaryCondition), ("EC", .necessaryCondition), ("GoalTree", .necessaryCondition),
        ("ConceptMap", .noLogic), ("IBIS", .noLogic), ("ImpactMapping", .noLogic), ("BBS", .noLogic),
    ])
    func aNotationInstallsItsDiagramLogic(notation: String, expected: DiagramLogic) throws {
        let entry = try #require(NotationRegistry.entry(for: notation))
        let graph = try VGraph().defineStandardAttributes().placing(entry.content, in: .builtin)

        let logicString: String = try graph.get(graphAttribute: Attributes.Group.diagramLogic)
        #expect(try DiagramLogic.fromString(logicString) == expected)
    }
}
