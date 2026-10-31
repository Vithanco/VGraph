import TestSupport
import Testing

@testable import VGraph

@Suite
struct DiagramLogicTests {

    // MARK: - Enum Tests

    @Test func testAllCasesCount() {
        #expect(DiagramLogic.allCases.count == 3)
    }

    @Test func testReadableNames() {
        #expect(DiagramLogic.noLogic.readableName == "None")
        #expect(DiagramLogic.sufficientCause.readableName == "Sufficient Cause")
        #expect(DiagramLogic.necessaryCondition.readableName == "Necessary Condition")
    }

    @Test func testFromStringRoundTrips() throws {
        for logic in DiagramLogic.allCases {
            let roundTripped = try DiagramLogic.fromString(logic.readableName)
            #expect(roundTripped == logic)
        }
    }

    @Test func testRelationshipNames() {
        #expect(DiagramLogic.noLogic.relationshipName == "points at")
        #expect(DiagramLogic.sufficientCause.relationshipName == "sufficient causes")
        #expect(DiagramLogic.necessaryCondition.relationshipName == "is necessary for")
    }

    @Test func testConnectionNames() {
        #expect(DiagramLogic.noLogic.connectionName == "connection")
        #expect(DiagramLogic.sufficientCause.connectionName == "sufficient cause")
        #expect(DiagramLogic.necessaryCondition.connectionName == "necessary condition")
    }

    // MARK: - Protocol Property Tests

    @Test func testSufficientCauseNotations() {
        #expect(Notations.CurrentRealityTree.diagramLogic == .sufficientCause)
        #expect(Notations.FutureRealityTree.diagramLogic == .sufficientCause)
        #expect(Notations.TransitionTree.diagramLogic == .sufficientCause)
        #expect(Notations.ADTree.diagramLogic == .sufficientCause)
    }

    @Test func testNecessaryConditionNotations() {
        #expect(Notations.PrerequisiteTree.diagramLogic == .necessaryCondition)
        #expect(Notations.EvaporatingCloud.diagramLogic == .necessaryCondition)
    }

    @Test func testNoLogicNotations() {
        #expect(Notations.ConceptMap.diagramLogic == .noLogic)
        #expect(Notations.Ibis.diagramLogic == .noLogic)
        #expect(Notations.ImpactMapping.diagramLogic == .noLogic)
        #expect(Notations.Bbs.diagramLogic == .noLogic)
    }

    // MARK: - Graph Attribute Tests

    @Test func testCRTStoresSufficientCauseAttribute() throws {
        var graph = try VGraph().defineStandardAttributes()
        graph = try Notations.CurrentRealityTree.addNotation(addTo: graph)

        let logicString: String = try graph.get(graphAttribute: Attributes.Group.diagramLogic)
        let logic = try DiagramLogic.fromString(logicString)
        #expect(logic == .sufficientCause)
    }

    @Test func testPRTStoresNecessaryConditionAttribute() throws {
        var graph = try VGraph().defineStandardAttributes()
        graph = try Notations.PrerequisiteTree.addNotation(addTo: graph)

        let logicString: String = try graph.get(graphAttribute: Attributes.Group.diagramLogic)
        let logic = try DiagramLogic.fromString(logicString)
        #expect(logic == .necessaryCondition)
    }

    @Test func testECStoresNecessaryConditionAttribute() throws {
        var graph = try VGraph().defineStandardAttributes()
        graph = try Notations.EvaporatingCloud.addNotation(addTo: graph)

        let logicString: String = try graph.get(graphAttribute: Attributes.Group.diagramLogic)
        let logic = try DiagramLogic.fromString(logicString)
        #expect(logic == .necessaryCondition)
    }

    @Test func testConceptMapStoresNoLogicAttribute() throws {
        var graph = try VGraph().defineStandardAttributes()
        graph = try Notations.ConceptMap.addNotation(addTo: graph)

        let logicString: String = try graph.get(graphAttribute: Attributes.Group.diagramLogic)
        let logic = try DiagramLogic.fromString(logicString)
        #expect(logic == .noLogic)
    }

    @Test func testIBISStoresNoLogicAttribute() throws {
        var graph = try VGraph().defineStandardAttributes()
        graph = try Notations.Ibis.addNotation(addTo: graph)

        let logicString: String = try graph.get(graphAttribute: Attributes.Group.diagramLogic)
        let logic = try DiagramLogic.fromString(logicString)
        #expect(logic == .noLogic)
    }
}
