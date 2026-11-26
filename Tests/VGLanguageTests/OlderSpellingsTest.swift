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

    enum DirectionPlace: CaseIterable {
        case body, view, vnotation

        func document(_ direction: String) -> String {
            func given(in place: DirectionPlace) -> String { self == place ? direction : "" }
            return """
                vnotation Work {
                	\(given(in: .vnotation))
                	node type: Task [nodeStyle: roundedBox]
                }

                vgraph plan: Work "Plan" {
                	\(given(in: .body))
                	node a: Task "A"
                }

                vview v [\(given(in: .view))] {
                }
                """
        }

        var layer: AttributeLayer {
            switch self {
            case .body: return .model
            case .view: return VGraph.layer(ofView: "v")
            case .vnotation: return .vnotation
            }
        }
    }

    private func direction(_ written: String, in place: DirectionPlace) throws -> LayoutDirection? {
        try parse(place.document(written)).value(Attributes.Group.layoutDirection, of: .root, through: place.layer)
    }

    private static let directionsWritten = [
        "rankdir: LR", "layout: leftToRight", "layoutDirection: leftToRight", "layoutDirection: LR",
        "layoutDirection: \"Left to Right\"",
    ]

    @Test(
        "Given a diagram direction in any spelling, when parsed, then it is the same direction",
        arguments: DirectionPlace.allCases, directionsWritten)
    func everyDirectionSpellingReads(place: DirectionPlace, written: String) throws {
        #expect(try direction(written, in: place) == .leftToRight)
    }

    @Test(
        "Given a diagram direction in any spelling, when exported, then it comes back as layoutDirection: leftToRight",
        arguments: DirectionPlace.allCases, directionsWritten)
    func exportWritesLayoutDirection(place: DirectionPlace, written: String) throws {
        let exported = try VGLExporter().export(graph: parse(place.document(written)))

        #expect(exported.components(separatedBy: "layoutDirection: leftToRight").count == 2, "\(exported)")
        #expect(try VGLExporter().export(graph: parse(exported)) == exported)
    }

    private static let lowerCaseKeys = """
        vnotation Work {
        	node type: Task [nodeStyle: simpleRoundedBox]
        	group type: Team
        }

        vgraph plan: Work "Plan" {
        	fontcolor: navy
        	node a: Task "A" [backgroundcolor: red; fontcolor: white]
        	group core: Team "Core" {
        		backgroundcolor: "#eeeeee"
        		bordercolor: gray
        		node b: Task "B"
        	}
        }

        vview v [fontcolor: black] {
        	node a [backgroundcolor: blue]
        	group core [isfolded: true]
        }
        """

    @Test("Given attributes in lower case, when exported, then each is written as the guide spells it")
    func exportWritesTheGuidesSpelling() throws {
        let exported = try VGLExporter().export(graph: parse(Self.lowerCaseKeys))

        #expect(exported.contains("\tfontColor: navy\n"))
        #expect(exported.contains("node a: Task \"A\" [backgroundColor: red, fontColor: white]\n"))
        #expect(exported.contains("\t\tbackgroundColor: \"#eeeeee\"\n\t\tborderColor: gray\n"))
        #expect(exported.contains("vview v [fontColor: black] {\n\tnode a [backgroundColor: blue]\n\tfolded group core\n}"))
    }

    @Test("Given a file with lower-case keys, when round-tripped, then it comes back in the guide's spelling and stays there")
    func lowerCaseRoundTripsToTheGuidesSpelling() throws {
        let exported = try VGLExporter().export(graph: parse(Self.lowerCaseKeys))
        let lowerCaseKeys = ["backgroundcolor", "fontcolor", "bordercolor", "isfolded"]

        #expect(lowerCaseKeys.allSatisfy { !exported.contains("\($0):") }, "\(exported)")
        #expect(try VGLExporter().export(graph: parse(exported)) == exported)
    }

    @Test("Given a direction that is none, when exported, then it is written back as the author wrote it")
    func anUnknownDirectionIsKept() throws {
        let exported = try VGLExporter().export(graph: parse(DirectionPlace.body.document("rankdir: sideways")))

        #expect(exported.contains("\tlayoutDirection: sideways\n"))
    }

    /// One attribute under two spellings, wherever a document can set one.
    enum Duplicate: CaseIterable {
        case node, group, graph, viewHeader, viewNode, viewAcrossStatements, vnotationHeader

        func document(_ written: String) -> String {
            func given(in places: Duplicate...) -> String { places.contains(self) ? written : "" }
            let separated = given(in: .viewAcrossStatements).split(separator: ",").map { "node a [\($0)]" }
            return """
                vnotation Work {
                	\(given(in: .vnotationHeader))
                	node type: Task [nodeStyle: simpleRoundedBox]
                	group type: Team
                }

                vgraph plan: Work "Plan" {
                	\(given(in: .graph))
                	node a: Task "A" [\(given(in: .node))]
                	group core: Team "Core" {
                		\(given(in: .group))
                		node b: Task "B"
                	}
                }

                vview v [\(given(in: .viewHeader))] {
                	node a [\(given(in: .viewNode))]
                	\(separated.joined(separator: "\n\t"))
                }
                """
        }

        var isColor: Bool {
            switch self {
            case .graph, .viewHeader, .vnotationHeader: return false
            case .node, .group, .viewNode, .viewAcrossStatements: return true
            }
        }

        var layer: AttributeLayer {
            switch self {
            case .node, .group, .graph: return .model
            case .viewHeader, .viewNode, .viewAcrossStatements: return VGraph.layer(ofView: "v")
            case .vnotationHeader: return .vnotation
            }
        }

        var stated: String {
            switch self {
            case .node: return #"Node "A" gives backgroundColor twice"#
            case .group: return #"Group "Core" gives backgroundColor twice"#
            case .graph, .vnotationHeader: return "The diagram gives layoutDirection twice"
            case .viewHeader: return #"The diagram gives layoutDirection twice in view "v""#
            case .viewNode, .viewAcrossStatements: return #"Node "A" gives backgroundColor twice in view "v""#
            }
        }
    }

    private func color(_ place: Duplicate, in graph: VGraph) -> VColor? {
        place == .group
            ? graph.value(Attributes.Group.backgroundColor, of: ItemKey(Group(rawValue: "core")), through: place.layer)
            : graph.value(Attributes.Node.backgroundColor, of: ItemKey(Node(rawValue: "a")), through: place.layer)
    }

    @Test(
        "Given an attribute in both spellings with different values, when parsed, then the current spelling holds and one warning names both",
        arguments: Duplicate.allCases, [true, false])
    func attributeGivenTwice(place: Duplicate, olderLast: Bool) throws {
        let older = place.isColor ? ##"color: "#aa0000""## : "rankdir: BT"
        let current = place.isColor ? ##"backgroundColor: "#0000aa""## : "layoutDirection: leftToRight"
        let separator = place == .graph || place == .group || place == .vnotationHeader ? "\n" : ","
        let source = place.document((olderLast ? [current, older] : [older, current]).joined(separator: separator))
        let graph = try parse(source)

        if place.isColor {
            #expect(color(place, in: graph) == VColor(hexString: "#0000aa"))
        } else {
            #expect(graph.value(Attributes.Group.layoutDirection, of: .root, through: place.layer) == .leftToRight)
        }
        let spelled =
            place.isColor
            ? "as color: #aa0000 and backgroundColor: #0000aa — using #0000aa"
            : "as rankdir: BT and layoutDirection: leftToRight — using leftToRight"
        #expect(try warnings(source).filter { $0.contains("twice") } == ["\(place.stated), \(spelled)"])
        #expect(try VGLExporter().export(graph: graph).contains(place.isColor ? "#aa0000" : "bottomToTop") == false)
    }

    @Test(
        "Given an attribute in both spellings with equal values, when parsed, then nothing is reported",
        arguments: Duplicate.allCases)
    func attributeGivenTwiceAlike(place: Duplicate) throws {
        let separator = place == .graph || place == .group || place == .vnotationHeader ? "\n" : ","
        let written =
            place.isColor
            ? [#"color: red"#, ##"backgroundColor: "#ff0000""##] : ["rankdir: LR", "layoutDirection: leftToRight"]
        let source = place.document(written.joined(separator: separator))

        #expect(try warnings(source) == warnings(place.document(written[1])))
        #expect(try VGLExporter().export(graph: parse(source)) == VGLExporter().export(graph: parse(place.document(written[1]))))
    }

    @Test("Given an attribute in two older spellings, when parsed, then the later one holds and one warning names both")
    func twoOlderSpellings() throws {
        let source = Duplicate.graph.document("layout: bottomToTop\nrankdir: LR")

        #expect(try parse(source).value(Attributes.Group.layoutDirection, of: .root, through: .model) == .leftToRight)
        #expect(
            try warnings(source).filter { $0.contains("twice") } == [
                "The diagram gives layoutDirection twice, as layout: bottomToTop and rankdir: LR — using LR"
            ])
    }

    @Test("Given a node coloured in two spellings, when analysed, then the warning points at the node")
    func theWarningPointsAtTheNode() throws {
        let graph = try parse(Duplicate.node.document(##"color: "#aa0000", backgroundColor: "#0000aa""##))

        let twice = try #require(Notations.analyzeQuality(graph: graph).warnings.first { $0.message.contains("twice") })
        #expect(twice.target == .node("a"))
    }

    @Test(
        "Given a node coloured in two spellings, when recoloured or deleted, then the warning about the old colour goes",
        arguments: ["#0000aa", "#ffffff"])
    func theWarningGoesWithItsValue(kept: String) throws {
        let graph = try parse(Duplicate.node.document(##"color: "#aa0000", backgroundColor: "\##(kept)""##))
        let node = Node(rawValue: "a")
        let recolored = try graph.setting(node: node, attribute: Attributes.Node.backgroundColor(VColor(hexString: "#00aa00")!))
        func isReported(_ graph: VGraph) -> Bool {
            Notations.analyzeQuality(graph: graph).warnings.contains { $0.message.contains("twice") }
        }

        #expect(isReported(graph))
        #expect(!isReported(recolored))
        #expect(!isReported(try graph.deleting(node: node)))
    }
    @Test(
        "Given an attribute twice in the same spelling with different values, when parsed, then the later holds and one warning names both",
        arguments: Duplicate.allCases)
    func sameSpellingTwice(place: Duplicate) throws {
        let separator = place == .graph || place == .group || place == .vnotationHeader ? "\n" : ","
        let written = place.isColor ? ["color: red", "color: blue"] : ["rankdir: BT", "rankdir: LR"]
        let source = place.document(written.joined(separator: separator))
        let graph = try parse(source)

        if place.isColor {
            #expect(color(place, in: graph) == VColor(hexString: "#0000ff"))
        } else {
            #expect(graph.value(Attributes.Group.layoutDirection, of: .root, through: place.layer) == .leftToRight)
        }
        let spelled = place.isColor ? "as color: red and color: blue — using blue" : "as rankdir: BT and rankdir: LR — using LR"
        #expect(try warnings(source).filter { $0.contains("twice") } == ["\(place.stated), \(spelled)"])
    }

    @Test(
        "Given an attribute twice in the same spelling with equal values, when parsed, then one warning still says so",
        arguments: Duplicate.allCases)
    func sameSpellingTwiceAlike(place: Duplicate) throws {
        let separator = place == .graph || place == .group || place == .vnotationHeader ? "\n" : ","
        let once = place.isColor ? "color: red" : "layoutDirection: leftToRight"
        let source = place.document([once, once].joined(separator: separator))
        let spelled =
            place.isColor
            ? "as color: red and color: red — using red"
            : "as layoutDirection: leftToRight and layoutDirection: leftToRight — using leftToRight"

        #expect(try warnings(source).filter { $0.contains("twice") } == ["\(place.stated), \(spelled)"])
        #expect(try warnings(place.document(once)).filter { $0.contains("twice") }.isEmpty)
    }

    @Test("Given a node coloured twice in the same spelling, when the duplicate is removed, then the warning goes")
    func theRepeatedSpellingsWarningGoes() throws {
        let twice = Duplicate.node.document("color: red, color: red")
        let once = Duplicate.node.document("color: red")

        #expect(try warnings(twice).count == warnings(once).count + 1)
        #expect(try warnings(VGLExporter().export(graph: parse(twice))) == warnings(once))
    }
    /// A group may be declared again, and its second body sets the same element.
    private func groupDeclaredTwice(_ first: String, _ second: String) -> String {
        """
        vgraph plan: IBIS "Plan" {
        	group core "Core" {
        		\(first)
        		node a: Question "A"
        	}
        	group core "Core" {
        		\(second)
        		node b: Question "B"
        	}
        }
        """
    }

    @Test(
        "Given a group declared twice, when both set one attribute, then the later holds and one warning names both",
        arguments: ["blue", "red"])
    func aGroupDeclaredAgain(second: String) throws {
        let source = groupDeclaredTwice("backgroundColor: red", "backgroundColor: \(second)")
        let graph = try parse(source)

        #expect(
            graph.value(Attributes.Group.backgroundColor, of: ItemKey(Group(rawValue: "core")), through: .model)
                == VColor(hexString: second == "blue" ? "#0000ff" : "#ff0000"))
        #expect(
            try warnings(source).filter { $0.contains("twice") } == [
                #"Group "Core" gives backgroundColor twice, as backgroundColor: red and backgroundColor: \#(second) — using \#(second)"#
            ])
    }

    @Test("Given a group declared twice, when each sets a different attribute, then nothing is reported")
    func aGroupDeclaredAgainWithOtherAttributes() throws {
        let source = groupDeclaredTwice("backgroundColor: red", "borderColor: blue")

        #expect(try warnings(source).filter { $0.contains("twice") }.isEmpty)
    }
}
