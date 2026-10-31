import Testing

@testable import VGLanguage
@testable import VGraph

/// ADR-0032: a detailed node holds node attributes on its group key and
/// resolves them group → node type.
@Suite("Detailed node attributes in VGL")
struct DetailedNodeAttributesVGLTest {

    private static let source = """
        vgraph arch: C4 "Architecture" {
            node customer: Person "Customer";
            group ibs: SoftwareSystem "Internet Banking System" {
                node web: Container "Web App";
            };
            edge customer -> web "uses";
        }
        """

    private let ibs = Group(rawValue: "ibs")

    private func parse(_ source: String) throws -> VGraph {
        try VGraphParser(logger: NoOpLogger()).parse(source: source)
    }

    @Test func theLabelSlotIsTheNodeLabel() throws {
        let graph = try parse(Self.source)

        #expect(try graph.get(group: ibs, attribute: Attributes.Node.label) == "Internet Banking System")
        #expect(graph.label(of: .group(ibs)) == "Internet Banking System")
    }

    /// As for a node, an absent label means the id.
    @Test func anUnlabelledDetailedNodeIsLabelledWithItsId() throws {
        let graph = try parse(
            """
            vgraph arch: C4 "Architecture" {
                group ibs: SoftwareSystem {
                    node web: Container "Web App";
                }
            }
            """)

        #expect(graph.label(of: .group(ibs)) == "ibs")
    }

    private static let overridden = """
        vgraph arch: C4 "Architecture" {
            node customer: Person "Customer";

            // the bank's core
            group ibs: SoftwareSystem "Internet Banking System" { // online only
                backgroundcolor: "#336699"
                fontsize: 18
                tooltip: "Lets customers bank online"
                url: "https://bank.example"
                node web: Container "Web App";
            }
            edge customer -> web "uses";
        }
        """

    @Test func nodeValuesInTheBodyAreTheNodesOwn() throws {
        let graph = try parse(Self.overridden)

        #expect(graph.url(of: .group(ibs)) == "https://bank.example")
        #expect(try graph.get(group: ibs, attribute: Attributes.Node.tooltip) == "Lets customers bank online")
        #expect(try graph.get(group: ibs, attribute: Attributes.Node.backgroundColor) == VColor(hexString: "#336699"))
        #expect(try graph.get(group: ibs, attribute: Attributes.Node.fontsize) == 18)
        #expect(try graph.get(group: ibs, attribute: Attributes.Node.comment) == "// the bank's core")
        #expect(try graph.get(group: ibs, attribute: Attributes.Node.trailingComment) == "// online only")
    }

    @Test func nodeValuesAndCommentsRoundTrip() throws {
        let first = try VGLExporter().export(graph: parse(Self.overridden))

        #expect(first.contains("\t// the bank's core\n\tgroup ibs: SoftwareSystem \"Internet Banking System\" {  // online only\n"))
        #expect(first.contains("\t\turl: \"https://bank.example\"\n"))
        #expect(first.contains("\t\ttooltip: \"Lets customers bank online\"\n"))
        #expect(!first.contains("label:"))
        #expect(try VGLExporter().export(graph: parse(first)) == first)
    }

    private static let typed = """
        vnotation Bank extends C4 {
            node type: SoftwareSystem [backgroundColor: "#aa0000", category: "System"]
        }

        vgraph arch: Bank "Architecture" {
            group ibs: SoftwareSystem "Internet Banking System" {
                category: "System"
                node web: Container "Web App";
            }
            group mainframe: SoftwareSystem "Mainframe" {
                category: "Host"
                node core: Container "Core";
            }
        }
        """

    @Test func aValueNotSetResolvesFromTheNodeType() throws {
        let graph = try parse(Self.typed)

        #expect(try graph.get(group: ibs, attribute: Attributes.Node.backgroundColor) == VColor(hexString: "#aa0000"))
    }

    @Test func aValueRepeatingTheNodeTypeIsNotWritten() throws {
        let exported = try VGLExporter().export(graph: parse(Self.typed))

        #expect(!exported.contains("\t\tcategory: System\n"))
        #expect(exported.contains("\t\tcategory: Host\n"))
    }

    @Test func aDetailedNodeThatOnlyRepeatedItsTypeFollowsTheTypesChange() throws {
        let mainframe = Group(rawValue: "mainframe")
        let system = Notations.C4.NodeTypes.softwareSystem
        let graph = try parse(Self.typed)
            .set(nodeType: system, attribute: Attributes.Node.category("Host"))
            .set(nodeType: system, attribute: Attributes.Node.category("Platform"))

        #expect(try graph.get(group: mainframe, attribute: Attributes.Node.category) == "Platform")
    }
}

@Suite("A detailed node in a view")
struct DetailedNodeInAViewTest {

    private static let source = """
        vgraph arch: C4 "Architecture" {
            group ibs: SoftwareSystem "Internet Banking System" {
                backgroundcolor: "#336699"
                node web: Container "Web App";
            }
            group mainframe: SoftwareSystem "Mainframe" {
                node core: Container "Core";
            }
        }

        vview focus "Focus" {
            node type: SoftwareSystem [backgroundcolor: "#0000aa"]
            group mainframe [backgroundcolor: "#00aa00", fontsize: 16]
        }
        """

    private func shown() throws -> VGraph {
        try VGraphParser(logger: NoOpLogger()).parse(source: Self.source).displaying(view: "focus")
    }

    @Test func aViewValueOnTheDetailedNodeApplies() throws {
        let graph = try shown()

        #expect(try graph.get(group: Group(rawValue: "mainframe"), attribute: Attributes.Node.backgroundColor) == VColor(hexString: "#00aa00"))
        #expect(try graph.get(group: Group(rawValue: "mainframe"), attribute: Attributes.Node.fontsize) == 16)
    }

    @Test func aViewValueOnTheNodeTypeBeatsTheModelValueOnTheDetailedNode() throws {
        #expect(try shown().get(group: Group(rawValue: "ibs"), attribute: Attributes.Node.backgroundColor) == VColor(hexString: "#0000aa"))
    }

    @Test func aViewValueOnADetailedNodeRoundTrips() throws {
        let first = try VGLExporter().export(graph: VGraphParser(logger: NoOpLogger()).parse(source: Self.source))

        #expect(first.contains("\tgroup mainframe [backgroundcolor: \"#00aa00\", fontsize: 16]\n"))
        #expect(try VGLExporter().export(graph: VGraphParser(logger: NoOpLogger()).parse(source: first)) == first)
    }
}

@Suite("What a group accepts")
struct GroupAttributeTargetTest {

    private static let source = """
        vgraph arch: C4 "Architecture" {
            group bank "Big Bank" {
                group ibs: SoftwareSystem "Internet Banking System" {
                    node web: Container "Web App";
                }
            }
        }
        """

    private let ibs = Group(rawValue: "ibs")
    private let bank = Group(rawValue: "bank")

    private func graph() throws -> VGraph {
        try VGraphParser(logger: NoOpLogger()).parse(source: Self.source)
    }

    @Test func aDetailedNodeRefusesAGroupAttributeANodeAttributeShadows() throws {
        let graph = try graph()

        #expect(throws: VError.wrongTarget(is: .graph, insteadOf: .node)) {
            try graph.set(group: ibs, attribute: Attributes.Group.label("Shadowed"))
        }
        #expect(throws: VError.wrongTarget(is: .graph, insteadOf: .node)) {
            try graph.set(group: ibs, attribute: Attributes.Group.url("https://bank.example"))
        }
    }

    @Test func aDetailedNodeRefusesAnEdgeAttribute() throws {
        #expect(throws: VError.wrongTarget(is: .edge, insteadOf: .node)) {
            try graph().set(group: ibs, attribute: Attributes.Edge.label("uses"))
        }
    }

    @Test func aDetailedNodeTakesItsFoldState() throws {
        let graph = try graph().set(group: ibs, attribute: Attributes.Group.isFolded(true))

        #expect(try graph.get(group: ibs, attribute: Attributes.Group.isFolded))
    }

    @Test func aPlainGroupRefusesNodeAndEdgeAttributes() throws {
        let graph = try graph()

        #expect(throws: VError.wrongTarget(is: .node, insteadOf: .graph)) {
            try graph.set(group: bank, attribute: Attributes.Node.label("Bank"))
        }
        #expect(throws: VError.wrongTarget(is: .edge, insteadOf: .graph)) {
            try graph.set(group: bank, attribute: Attributes.Edge.label("Bank"))
        }
    }
}
