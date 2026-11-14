// A missing icon degrades the drawing instead of aborting it (ADR-0022), so
// without this the mistake is invisible in diagram, report and source at once —
// the failure mode ADR-0020 named for group types.

import Testing
import VGLanguage
import VGraph

@Suite("The report on an icon that resolves to nothing")
struct UnresolvableIconTests {

    private func parse(_ vgl: String) throws -> VGraph {
        try VGraphParser(logger: NoOpLogger()).parse(source: vgl)
    }

    private func iconMessages(_ graph: VGraph) -> [MessageWithSeverity] {
        GenericQualityChecks.unresolvableIcons(graph: graph)
    }

    @Test("A notation whose icons all resolve says nothing")
    func aGoodNotationIsQuiet() throws {
        let graph = try parse(
            """
            vnotation Gates {
                node type: Gate [nodeStyle: iconWithText, backgroundColor: "#339933", icon: "and"]
                edge type: rel from: Gate to: Gate
            }

            vgraph g: Gates "Fine" {
                node g1: Gate "Both";
            }
            """)

        #expect(iconMessages(graph).isEmpty)
    }

    @Test("A node type that draws no icon says nothing")
    func anIconlessStyleIsQuiet() throws {
        let graph = try parse(
            """
            vnotation Plain {
                node type: Box [nodeStyle: roundedBox, backgroundColor: "#339933"]
                edge type: rel from: Box to: Box
            }

            vgraph p: Plain "Plain" {
                node b1: Box "B";
            }
            """)

        #expect(iconMessages(graph).isEmpty)
    }

    @Test("It reports a node type once, not once per node")
    func itReportsThePerTypeMistakeOnce() throws {
        let graph = try parse(
            """
            vnotation RiskMap {
                node type: Control [nodeStyle: iconWithText, backgroundColor: "#339933", icon: "shield"]
                edge type: rel from: Control to: Control
            }

            vgraph rm: RiskMap "Risks" {
                node c1: Control "One";
                node c2: Control "Two";
                node c3: Control "Three";
            }
            """)

        #expect(iconMessages(graph).count == 1)
    }

    @Test("It is one of the checks that always run")
    func itIsWiredIntoTheStandardSet() throws {
        let graph = try parse(
            """
            vnotation RiskMap {
                node type: Control [nodeStyle: iconWithText, backgroundColor: "#339933", icon: "shield"]
                edge type: rel from: Control to: Control
            }

            vgraph rm: RiskMap "Risks" {
                node c1: Control "Weekly reviews";
            }
            """)

        #expect(GenericQualityChecks.analyze(graph).contains { $0.message.contains("shield") })
    }

    @Test("Given a vnotation node type naming lightbulb.fill, when its quality is checked, then a warning names the node type and the icon")
    func aMarkVGraphNoLongerShipsIsReported() throws {
        let graph = try parse(
            """
            vnotation Ideas {
                node type: Idea [nodeStyle: iconWithText, backgroundColor: "#f0c040", icon: "lightbulb.fill"]
                edge type: rel from: Idea to: Idea
            }

            vgraph i: Ideas "Ideas" {
                node i1: Idea "Ship it";
            }
            """)

        let messages = iconMessages(graph)
        #expect(messages.map { $0.message } == [#"Node type "Idea" uses an unknown icon "lightbulb.fill""#])
        #expect(messages.allSatisfy { $0.severity == .warning })
    }
}
