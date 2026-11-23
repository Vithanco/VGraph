import TestSupport
import Testing
import VGraph

@testable import App

@Suite("A vnotation names a quality check that does not exist")
struct UnknownQualityCheckTests {
    private let app = VGraphTestApp()

    @Test("Given a misspelled quality check, when rendered, then the diagram draws and the report names the known checks")
    func aMisspelledCheckIsReported() throws {
        let source = """
            vnotation Plan {
            	node type: Task [nodeStyle: roundedBox]
            	edge type: then from: Task to: Task
            	qualityCheck: treeStucture
            }

            vgraph plan: Plan "Plan" {
            	node write: Task "Write"
            }
            """

        let result = try app.renderGraph(source)

        #expect(result.svg.contains("Write"))
        #expect(
            result.qualityReport.warnings.map { $0.message }.contains(
                "Unknown quality check 'treeStucture'. Available: treeStructure, disconnectedNodes, noParallelEdges, "
                    + "redundantJunctor, exactlyOne, nodeCountRange, labelLength"))
    }
}
