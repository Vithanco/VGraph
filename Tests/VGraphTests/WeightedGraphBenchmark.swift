// Timings, not assertions: run with
//   VGRAPH_BENCH=1 swift test -c release -Xswiftc -enable-testing --filter WeightedGraphBenchmark
// Each operation is timed at doubling sizes, so the growth rate shows directly.

import Foundation
import Testing

@testable import VGraph

@Suite("WeightedGraph benchmark", .enabled(if: ProcessInfo.processInfo.environment["VGRAPH_BENCH"] != nil))
struct WeightedGraphBenchmark {

    private func ms(_ work: () -> Void) -> Double {
        let clock = ContinuousClock()
        let elapsed = clock.measure(work)
        return Double(elapsed.components.attoseconds) / 1e15 + Double(elapsed.components.seconds) * 1000
    }

    /// `prepare` runs untimed, so a row measures its operation and not the graph
    /// it needs. Best of three runs, to damp scheduler noise.
    private func report<T>(_ name: String, _ sizes: [Int], prepare: (Int) -> T, run: (T) -> Void) {
        let times = sizes.map { n in
            let input = prepare(n)
            return (0..<3).map { _ in ms { run(input) } }.min()!
        }
        let cells = zip(sizes, times).map { "n=\($0.0): \(String(format: "%8.2f", $0.1)) ms" }
        print("BENCH \(name.padding(toLength: 26, withPad: " ", startingAt: 0)) " + cells.joined(separator: "  "))
    }

    /// n vertices, each with two outgoing edges: a ring plus a chord.
    private func names(_ n: Int) -> [String] { (0..<n).map { "n\($0)" } }
    private func ringWithChords(_ n: Int) -> [(String, String, String)] {
        (0..<n).flatMap { i in
            [("r\(i)", "n\(i)", "n\((i + 1) % n)"), ("c\(i)", "n\(i)", "n\((i * 7 + 3) % n)")]
        }
    }

    @Test func benchmark() {
        let sizes = [1000, 2000, 4000]

        report(
            "build (addVertex/addLine)", sizes, prepare: { $0 },
            run: { n in
                _ = storage(names(n), ringWithChords(n))
            })

        let graphs = { (n: Int) in storage(names(n), ringWithChords(n)) }

        report(
            "lookup node, every one", sizes, prepare: graphs,
            run: { graph in
                for node in graph.vertices { _ = graph.has(node: node) }
            })

        report(
            "get(edge:), every edge", sizes, prepare: graphs,
            run: { graph in
                for edge in graph.getEdges() { _ = graph.get(edge: edge.id) }
            })

        report(
            "edgeExists, every edge", sizes, prepare: graphs,
            run: { graph in
                for edge in graph.getEdges() { _ = graph.edgeExists(from: edge.from, to: edge.to) }
            })

        report(
            "removeVertex until empty", sizes, prepare: graphs,
            run: { start in
                var graph = start
                while let last = graph.vertices.last { graph = graph.removeVertex(last) }
            })

        // Cycle enumeration is exponential in general, so the shapes are chosen to
        // grow polynomially: disjoint triangles (many short loops, the usual CLD),
        // and one ring (a single long walk).
        report(
            "detectCycles, triangles", sizes,
            prepare: { n in
                storage(
                    names(n),
                    (0..<n / 3).flatMap { t in
                        (0..<3).map { k in ("t\(t)_\(k)", "n\(3 * t + k)", "n\(3 * t + (k + 1) % 3)") }
                    })
            }, run: { graph in _ = graph.findLoops() })

        report(
            "detectCycles, one ring", [100, 200, 400],
            prepare: { n in
                storage(names(n), (0..<n).map { i in ("r\(i)", "n\(i)", "n\((i + 1) % n)") })
            }, run: { graph in _ = graph.findLoops() })

        report(
            "VGraph add node+edge", [250, 500, 1000], prepare: { $0 },
            run: { n in
                var graph = VGraph()
                let type = NodeType(string: "T")
                let edgeType = EdgeType(id: "t", from: type, to: type)
                graph = try! graph.add(nodeType: type).add(edgeType: edgeType)
                for i in 0..<n {
                    graph = try! graph.add(node: Node(string: "n\(i)"), type: type)
                    if i > 0 {
                        graph = try! graph.add(edge: Edge(string: "e\(i)", from: "n\(i - 1)", to: "n\(i)"), edgeType: edgeType)
                    }
                }
            })

        // What an editor does on every render: read an attribute of every edge.
        let chain = { (n: Int) -> VGraph in
            var graph = VGraph()
            let type = NodeType(string: "T")
            let edgeType = EdgeType(id: "t", from: type, to: type)
            graph = try! graph.add(nodeType: type).add(edgeType: edgeType)
            for i in 0..<n {
                graph = try! graph.add(node: Node(string: "n\(i)"), type: type)
                if i > 0 {
                    graph = try! graph.add(edge: Edge(string: "e\(i)", from: "n\(i - 1)", to: "n\(i)"), edgeType: edgeType)
                }
            }
            return graph
        }

        report(
            "VGraph read every edge label", [250, 500, 1000], prepare: chain,
            run: { graph in
                for edge in graph.edges { _ = try? graph.get(edge: edge.id, attribute: Attributes.Edge.label) }
            })

        report(
            "VGraph delete every node", [250, 500, 1000], prepare: chain,
            run: { start in
                var graph = start
                for node in start.nodes { graph = try! graph.delete(node: node) }
            })
    }
}
