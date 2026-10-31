import TestSupport
import Testing
import VGraph

@testable import App

/// A vnotation gives node types and group types their boundary look with
/// `boundaryDash`, `boundaryColor`, `boundaryFill` and `boundaryRadius`.
@Suite("A vnotation declares a boundary look")
struct VNotationBoundaryTests {
    private let app = VGraphTestApp()

    private func boundary(of group: String, in svg: String) -> Substring? {
        guard let start = svg.range(of: "id=\"group-\(group)\"") else { return nil }
        let rest = svg[start.upperBound...]
        guard let rect = rest.range(of: "<rect"), let end = rest[rect.lowerBound...].range(of: "/>") else { return nil }
        return rest[rect.lowerBound..<end.upperBound]
    }

    @Test("Given a detailable node type with a boundary, when a detailed node of it is unfolded, then it draws that boundary")
    func aNodeTypesBoundary() throws {
        let source = """
            vnotation Work {
            	node type: Project [nodeStyle: roundedBox, detailedBy: (Task), boundaryDash: "2,5", boundaryColor: "#123456", boundaryFill: "#fafafa", boundaryRadius: 3]
            	node type: Task [nodeStyle: roundedBox]
            }

            vgraph plan: Work "Plan" {
            	group launch: Project "Launch" {
            		isfolded: false
            		node write: Task "Write"
            	}
            }
            """

        let rect = try #require(boundary(of: "launch", in: try app.renderGraph(source).svg))

        #expect(rect.contains("stroke-dasharray=\"2,5\""))
        #expect(rect.contains("stroke=\"#123456\""))
        #expect(rect.contains("fill=\"#fafafa\""))
        #expect(rect.contains("rx=\"3"))
    }

    @Test("Given a group type with a boundary, when a group of it is drawn, then it draws that boundary")
    func aGroupTypesBoundary() throws {
        let source = """
            vnotation Teams {
            	node type: Member [nodeStyle: roundedBox]
            	group type: Team [boundaryDash: "", boundaryColor: "#aa0000"]
            }

            vgraph org: Teams "Org" {
            	group core: Team "Core" {
            		node ann: Member "Ann"
            	}
            }
            """

        let rect = try #require(boundary(of: "core", in: try app.renderGraph(source).svg))

        #expect(!rect.contains("stroke-dasharray"))
        #expect(rect.contains("stroke=\"#aa0000\""))
    }

    @Test("Given a vnotation overriding one boundary key of an inherited group type, then the other keys keep the base look")
    func anOverrideKeepsTheRest() throws {
        let source = """
            vnotation MyC4 extends C4 {
            	group type: Organisation [boundaryColor: "#00aa00"]
            }

            vgraph g: MyC4 "G" {
            	group bank: Organisation "Big Bank" {
            		node clerk: Person "Clerk"
            	}
            }
            """

        let rect = try #require(boundary(of: "bank", in: try app.renderGraph(source).svg))

        #expect(rect.contains("stroke=\"#00aa00\""))
        #expect(rect.contains("stroke-dasharray=\"8,4\""))
    }

    @Test("Given a detailable node type without boundary keys, when unfolded, then it keeps the generic cluster look")
    func noKeysNoBoundary() throws {
        let source = """
            vnotation Work {
            	node type: Project [nodeStyle: roundedBox, detailedBy: (Task)]
            	node type: Task [nodeStyle: roundedBox]
            }

            vgraph plan: Work "Plan" {
            	group launch: Project "Launch" {
            		isfolded: false
            		node write: Task "Write"
            	}
            }
            """

        let rect = try #require(boundary(of: "launch", in: try app.renderGraph(source).svg))

        #expect(rect.contains("stroke-dasharray=\"6,3\""))
    }
}
