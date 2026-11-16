import TestSupport
import Testing

@testable import App
@testable import VGraph
@testable import VGraphvizLib

@Suite("Align groups in DOT")
struct AlignGroupDotTests {

    private func dot(_ source: String) throws -> String {
        try DotExporter().export(graph: VGraphTestApp().parseGraph(source))
    }

    /// Graphviz only honours `rank=same` across clusters under `newrank`.
    @Test
    func nodesSharingAnAlignGroupAreRankedTogether() throws {
        let output = try dot(
            """
            vgraph myTimeline: Timeline "19th Century Europe" {
                node t1800: TimePoint "1800" [alignGroup: "1800"]
                node t1850: TimePoint "1850" [alignGroup: "1850"]
                node t1871: TimePoint "1871" [alignGroup: "1871"]
                edge t1800 -> t1850: sequence
                edge t1850 -> t1871: sequence

                group germany "Germany" {
                    node g1: Event "Napoleon defeats Prussia" [alignGroup: "1800"]
                    node g2: Event "German Unification" [alignGroup: "1871"]
                }
                group england "England" {
                    node e1: Event "Industrial Revolution peaks" [alignGroup: "1850"]
                    node e2: Event "Franco-Prussian War impact" [alignGroup: "1871"]
                }
            }
            """)

        #expect(output.contains("newrank=true;"))
        #expect(output.contains("rankdir=\"LR\""))
        #expect(output.contains("\t{ rank=same; t1800; g1; }\n"))
        #expect(output.contains("\t{ rank=same; t1850; e1; }\n"))
        #expect(output.contains("\t{ rank=same; t1871; g2; e2; }\n"))
        #expect(output.components(separatedBy: "rank=same").count == 4)
    }

    @Test
    func aLoneNodeInAnAlignGroupIsNotRanked() throws {
        let output = try dot(
            """
            vgraph simple: Timeline "Simple Timeline" {
                node e1: Event "Event A" [alignGroup: "phase1"]
                node e2: Event "Event B" [alignGroup: "phase1"]
                node e3: Event "Event C" [alignGroup: "phase2"]
                edge e1 -> e3: influence
            }
            """)

        #expect(output.contains("\t{ rank=same; e1; e2; }\n"))
        #expect(output.components(separatedBy: "rank=same").count == 2)
    }
}
