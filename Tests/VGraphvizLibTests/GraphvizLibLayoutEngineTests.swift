import Testing
import VGraph
import VGraphvizLib

@Suite("GraphvizLibLayoutEngine Tests")
struct GraphvizLibLayoutEngineTests {

    let engine = GraphvizLibLayoutEngine()

    @Test("Simple graph layout returns node positions")
    func simpleGraphLayout() throws {
        let dot = """
            digraph {
                a -> b
                b -> c
            }
            """

        let layout = try engine.computeLayout(dot: dot, engine: "dot")

        #expect(layout.nodePositions.count == 3)
        #expect(layout.nodePositions["a"] != nil)
        #expect(layout.nodePositions["b"] != nil)
        #expect(layout.nodePositions["c"] != nil)
    }

    @Test("Edge layouts are extracted with spline points")
    func edgeLayoutExtraction() throws {
        let dot = """
            digraph {
                a -> b [id="e1"]
            }
            """

        let layout = try engine.computeLayout(dot: dot, engine: "dot")

        #expect(layout.edgeLayouts.count == 1)
        let edgeLayout = layout.edgeLayouts["e1"]
        #expect(edgeLayout != nil)
        #expect(!edgeLayout!.splinePoints.isEmpty)
    }

    @Test("Cluster bounding boxes are extracted")
    func clusterExtraction() throws {
        let dot = """
            digraph {
                subgraph cluster_group1 {
                    label="Group 1"
                    a; b
                }
                a -> b
            }
            """

        let layout = try engine.computeLayout(dot: dot, engine: "dot")

        #expect(layout.groupLayouts["group1"] != nil)
        let groupLayout = layout.groupLayouts["group1"]!
        #expect(groupLayout.boundingBox.size.width > 0)
        #expect(groupLayout.boundingBox.size.height > 0)
    }

    @Test("Arrow heads are synthesized")
    func arrowHeadSynthesis() throws {
        let dot = """
            digraph {
                a -> b [id="e1"]
            }
            """

        let layout = try engine.computeLayout(dot: dot, engine: "dot")
        let edgeLayout = layout.edgeLayouts["e1"]!

        #expect(edgeLayout.arrowHead != nil)
        if case .polygon(let points) = edgeLayout.arrowHead!.shape {
            #expect(points.count == 3)  // triangle
        } else {
            Issue.record("Expected polygon arrow shape")
        }
    }

    @Test("Neato layout engine works")
    func neatoEngine() throws {
        let dot = """
            graph {
                a -- b
                b -- c
                c -- a
            }
            """

        let layout = try engine.computeLayout(dot: dot, engine: "neato")
        #expect(layout.nodePositions.count == 3)
    }

    @Test("Y coordinates are flipped (top-left origin)")
    func yCoordinateFlipping() throws {
        let dot = """
            digraph {
                rankdir=TB
                a -> b
            }
            """

        let layout = try engine.computeLayout(dot: dot, engine: "dot")
        let aPos = layout.nodePositions["a"]!
        let bPos = layout.nodePositions["b"]!

        // In top-to-bottom layout with Y-flip, "a" (rank 0) should have smaller Y than "b" (rank 1)
        #expect(aPos.y < bPos.y)
    }

    @Test("Cluster with cross-cluster edges is laid out correctly")
    func clusterWithCrossEdges() throws {
        // Regression: Graphviz WASM crashes with "table index is out of bounds" when using
        // json format for graphs that have cluster subgraphs with cross-cluster edges.
        // The fix routes those graphs through json0 format. This test verifies that the
        // layout pipeline handles such graphs end-to-end (native path).
        let dot = """
            digraph {
                subgraph cluster_groupA {
                    label="Group A"
                    n1 [fixedsize=true width=1 height=0.7 label="Node 1"]
                    n2 [fixedsize=true width=1 height=0.7 label="Node 2"]
                }
                n3 [fixedsize=true width=1 height=0.5 label="Node 3"]
                n1 -> n2 [id="e1"]
                n3 -> n1 [id="e2"]
                n2 -> n3 [id="e3"]
            }
            """

        let layout = try engine.computeLayout(dot: dot, engine: "dot")

        // All 3 nodes have positions
        #expect(layout.nodePositions.count == 3)
        #expect(layout.nodePositions["n1"] != nil)
        #expect(layout.nodePositions["n2"] != nil)
        #expect(layout.nodePositions["n3"] != nil)

        // All 3 edges have spline points
        #expect(layout.edgeLayouts.count == 3)
        #expect(layout.edgeLayouts["e1"]?.splinePoints.isEmpty == false)
        #expect(layout.edgeLayouts["e2"]?.splinePoints.isEmpty == false)
        #expect(layout.edgeLayouts["e3"]?.splinePoints.isEmpty == false)

        // Cluster bounding box is extracted
        #expect(layout.groupLayouts["groupA"] != nil)
        let groupA = layout.groupLayouts["groupA"]!
        #expect(groupA.boundingBox.size.width > 0)
        #expect(groupA.boundingBox.size.height > 0)
    }

    @Test("Edge labels are extracted")
    func edgeLabelExtraction() throws {
        let dot = """
            digraph {
                a -> b [id="e1", label="test label"]
            }
            """

        let layout = try engine.computeLayout(dot: dot, engine: "dot")
        let edgeLayout = layout.edgeLayouts["e1"]!

        #expect(edgeLayout.label != nil)
        #expect(edgeLayout.label!.text == "test label")
    }
}
