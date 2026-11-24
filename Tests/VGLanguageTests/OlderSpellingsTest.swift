import Testing

@testable import VGLanguage
@testable import VGraph

/// A document written with an older spelling reads as the current one, in the
/// body and in a `vnotation` alike, and is saved in the current spelling.
@Suite("Older VGL spellings")
struct OlderSpellingsTest {

    private func parse(_ source: String) throws -> VGraph {
        try VGraphParser(logger: NoOpLogger()).parse(source: source)
    }

    private func document(groupAttribute: String, typeKeys: String) -> String {
        """
        vnotation Work {
        	node type: Project [nodeStyle: roundedBox, detailedBy: (Task), \(typeKeys)]
        	node type: Task [nodeStyle: roundedBox]
        	group type: Team [\(typeKeys)]
        }

        vgraph plan: Work "Plan" {
        	group launch: Project "Launch" {
        		node write: Task "Write"
        	}
        	group core: Team "Core" {
        		\(groupAttribute): "3.0|2,5|#123456ff|#fafafaff"
        		node meet: Task "Meet"
        	}
        }
        """
    }

    private static let olderTypeKeys = ##"boundaryDash: "1,1", boundaryColor: "#aa0000", boundaryFill: "#eeeeee", boundaryRadius: 2"##
    private static let currentTypeKeys = ##"frameDash: "1,1", frameColor: "#aa0000", frameFill: "#eeeeee", frameRadius: 2"##

    private var older: String { document(groupAttribute: "boundaryChrome", typeKeys: Self.olderTypeKeys) }
    private var current: String { document(groupAttribute: "frame", typeKeys: Self.currentTypeKeys) }

    @Test("Given boundaryChrome on a group, when parsed, then the group has the frame that frame: gives it")
    func boundaryChromeIsFrame() throws {
        let core = Group(rawValue: "core")
        let expected = GroupFrame(
            cornerRadius: 3, borderDash: "2,5", borderColor: .literal(VColor(hexString: "#123456")!),
            fill: .literal(VColor(hexString: "#fafafa")!))

        #expect(try parse(older).resolvedFrame(core) == expected)
        #expect(try parse(current).resolvedFrame(core) == expected)
    }

    @Test("Given the boundary keys in a vnotation, when parsed, then the types have the frames the frame keys give them")
    func boundaryKeysAreFrameKeys() throws {
        let expected = GroupFrame(
            cornerRadius: 2, borderDash: "1,1", borderColor: .literal(VColor(hexString: "#aa0000")!),
            fill: .literal(VColor(hexString: "#eeeeee")!))
        for source in [older, current] {
            let graph = try parse(source)
            #expect(graph.resolvedFrame(Group(rawValue: "launch")) == expected)
            #expect(graph.value(Attributes.Group.frame, of: ItemKey(GroupType(rawValue: "Team")), through: .vnotation) == expected)
        }
    }

    @Test("Given a frame, when exported, then it is written in the current spelling")
    func exportWritesTheCurrentSpelling() throws {
        let exported = try VGLExporter().export(graph: parse(current))

        #expect(exported.contains("\t\tframe: \"3.0|2,5|#123456ff|#fafafaff\"\n"))
        #expect(exported.contains("detailedBy: (Task), frameDash: \"1,1\", frameColor: \"#aa0000\", frameFill: \"#eeeeee\", frameRadius: 2]\n"))
        #expect(exported.contains("\tgroup type: Team [frameDash: \"1,1\", frameColor: \"#aa0000\", frameFill: \"#eeeeee\", frameRadius: 2]\n"))
    }

    @Test("Given a file in the older spelling, when round-tripped, then it comes back in the current spelling")
    func roundTripUpdatesTheSpelling() throws {
        let exported = try VGLExporter().export(graph: parse(older))

        #expect(exported == (try VGLExporter().export(graph: parse(current))))
        #expect(!exported.contains("boundary"))
    }

    @Test("Given color: among a vnotation's diagram attributes, when parsed, then it sets what color: on the diagram sets")
    func colorInAVNotationIsTheDiagramsBackground() throws {
        let inBlock = try parse(
            """
            vnotation Tinted {
            	color: "#ffeecc"
            	node type: Thing [nodeStyle: roundedBox]
            }

            vgraph g: Tinted "G" {
            	node a: Thing "A"
            }
            """)
        let inBody = try parse(
            """
            vnotation Plain {
            	node type: Thing [nodeStyle: roundedBox]
            }

            vgraph g: Plain "G" {
            	color: "#ffeecc"
            	node a: Thing "A"
            }
            """)

        #expect(try inBlock.get(graphAttribute: Attributes.Group.backgroundColor) == "#ffeecc")
        #expect(try inBody.get(graphAttribute: Attributes.Group.backgroundColor) == "#ffeecc")
    }

    private func team(_ typeKeys: String) -> String {
        """
        vnotation Work {
        	node type: Task [nodeStyle: roundedBox]
        	group type: Team [\(typeKeys)]
        }

        vgraph plan: Work "Plan" {
        	group core: Team "Core" {
        		node meet: Task "Meet"
        	}
        }
        """
    }

    private func teamFrame(_ graph: VGraph) -> GroupFrame? {
        graph.value(Attributes.Group.frame, of: ItemKey(GroupType(rawValue: "Team")), through: .vnotation)
    }

    private func warnings(_ source: String) throws -> [String] {
        Notations.analyzeQuality(graph: try parse(source)).warnings.map { $0.message }
    }

    @Test("Given a frame key in both spellings with equal values, when parsed, then nothing is reported")
    func bothSpellingsAgreeing() throws {
        #expect(try warnings(team(#"boundaryDash: "1,1", frameDash: "1,1""#)) == warnings(team(#"frameDash: "1,1""#)))
    }

    @Test("Given a frame key in both spellings with different values, when parsed, then the current spelling holds and one warning names both")
    func bothSpellingsDisagreeing() throws {
        let source = team(#"frameDash: "1,1", boundaryDash: "4,4""#)

        #expect(try teamFrame(parse(source))?.borderDash == "1,1")
        #expect(
            try warnings(source) == [
                #"Group type "Team" gives frameDash twice, as boundaryDash: 4,4 and frameDash: 1,1 — using 1,1"#
            ] + warnings(team(#"frameDash: "1,1""#)))
    }

    @Test(
        "Given a vnotation key in another case, when parsed and exported, then it is read and written as the guide spells it",
        arguments: ["framedash", "FRAMEDASH"])
    func keysIgnoreCase(key: String) throws {
        let graph = try parse(team("\(key): \"1,1\""))

        #expect(teamFrame(graph)?.borderDash == "1,1")
        #expect(try VGLExporter().export(graph: graph).contains("\tgroup type: Team [frameDash: \"1,1\"]\n"))
    }

    @Test("Given the other keys of a vnotation in another case, when parsed, then each is read")
    func everyKeyIgnoresCase() throws {
        let graph = try parse(
            """
            vnotation Work {
            	QUALITYCHECK: noParallelEdges
            	node type: Project [NODESTYLE: withCategory, BACKGROUNDCOLOR: "#112233", CATEGORY: "P", FONTSIZE: 20, DETAILEDBY: (Task)]
            	node type: Task [nodeStyle: roundedBox]
            	edge type: needs  from: Task  to: Task [ARROWHEAD: none, OUTDEGREEMAX: 2]
            }

            vgraph plan: Work "Plan" {
            	node a: Task "A"
            }
            """)
        let project = NodeType(rawValue: "Project")
        let needs = EdgeType.Id(rawValue: "needs")

        #expect(try graph.get(nodeType: project, attribute: Attributes.Node.nodeStyle) == .withCategory)
        #expect(try graph.get(nodeType: project, attribute: Attributes.Node.backgroundColor) == VColor(hexString: "#112233"))
        #expect(try graph.get(nodeType: project, attribute: Attributes.Node.category) == "P")
        #expect(try graph.get(nodeType: project, attribute: Attributes.Node.fontsize) == 20)
        #expect(graph.detailTypes(of: project) == [NodeType(rawValue: "Task")])
        #expect(try graph.get(edgeType: needs, attribute: Attributes.Edge.arrowHead) == "none")
        #expect(try graph.get(edgeType: needs, attribute: Attributes.Edge.outDegreeMax) == 2)
        #expect(graph.notationDefinition.declaredQualityChecks.map { $0.name } == ["noParallelEdges"])
    }
}
