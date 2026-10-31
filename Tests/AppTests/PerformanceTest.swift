import Foundation
import Testing
import VGraph

struct PerformanceTest {

    var ntNumber = 1_000_000
    var nNumber = 2_000_000
    var etNumber = 3_000_000
    var eNumber = 4_000_000
    var gNumber = 5_000_000

    @Test mutating func VGraphTestWith1000() async throws {
        var graph = VGraph()
        var lastTime: Date = Date()

        for i in 1...1000 {
            graph = try addToGraph(graph: graph)
            if i % 1000 == 0 {
                let now: Date = Date()
                let timePassed: TimeInterval = now.timeIntervalSince(lastTime)
                lastTime = now
                debugPrint("Time passed: \(timePassed) seconds, progress: \(i)")
            }
        }
    }

    mutating func addToGraph(graph: VGraph) throws(VError) -> VGraph {
        var graph = graph

        let nodeType = NodeType(string: nextNodeTypeName())
        let n1 = Node(string: nextNodeNumber())
        let n2 = Node(string: nextNodeNumber())

        let et1 = EdgeType(id: nextEdgeTypeNumber(), from: nodeType, to: nodeType)
        let e1 = Edge(id: nextEdgeNumber(), from: n1, to: n2)
        let e2 = Edge(id: nextEdgeNumber(), from: n2, to: n1)

        let g = Group(rawValue: nextGroupNumber())

        graph = try graph.add(nodeType: nodeType)
            .add(group: g)
            .add(node: n1, type: nodeType)
            .add(node: n2, type: nodeType, group: g)
            .add(edgeType: et1)
            .add(edge: e1, edgeType: et1)
            .add(edge: e2, edgeType: et1)

            .set(node: n1, def: Attributes.Node.label, value: "Hello World!")
            .set(node: n2, def: Attributes.Node.label, value: "Hello World-2!")
            .set(edge: e1, def: Attributes.Edge.label, value: "Hello World-3!")
            .set(edge: e2, def: Attributes.Edge.label, value: "Hello World-4!")

        return graph
    }

    mutating func nextNodeTypeName() -> String {
        ntNumber += 1
        return "nodeType \(ntNumber)"
    }

    mutating func nextNodeNumber() -> String {
        nNumber += 1
        return "node \(nNumber)"
    }

    mutating func nextEdgeNumber() -> String {
        eNumber += 1
        return "edge \(eNumber)"
    }

    mutating func nextEdgeTypeNumber() -> String {
        etNumber += 1
        return "edgeType \(etNumber)"
    }

    mutating func nextGroupNumber() -> String {
        gNumber += 1
        return "group \(gNumber)"
    }

}
