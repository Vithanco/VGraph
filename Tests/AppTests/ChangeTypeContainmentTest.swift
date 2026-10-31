import EditorCore
import Testing
import VGraph

@testable import App

/// Change type follows ADR-0032's one rule for placement: without ⌥ it offers
/// only what the containment check accepts; with ⌥ anything goes and the check
/// says what no longer fits.
@Suite("Change type follows containment")
struct ChangeTypeContainmentTest {

    private static let notation = """
        vnotation Arch {
        	node type: Person [nodeStyle: roundedBox]
        	node type: System [nodeStyle: roundedBox, detailedBy: (Container, Database, Queue)]
        	node type: Container [nodeStyle: roundedBox, detailedBy: (Component)]
        	node type: Database [nodeStyle: roundedBox, detailedBy: (Table)]
        	node type: Queue [nodeStyle: roundedBox, detailedBy: (Component, Table)]
        	node type: Component [nodeStyle: roundedBox]
        	node type: Table [nodeStyle: roundedBox]
        }

        """

    private func session(_ body: String) throws -> TestSession {
        try makeTestSession(vgl: Self.notation + "vgraph g: Arch \"G\" {\n" + body + "\n}\n")
    }

    private func types(_ types: [NodeType]) -> [String] {
        types.map { $0.id }
    }

    @Test("Given a node inside a detailed node, then only that node's detail types are offered")
    func aDetailIsOfferedItsHoldersDetailTypes() throws {
        let s = try session(
            """
            	group ibs: System "Internet Banking" {
            		group front "Front End" {
            			node web: Container "Web App";
            		};
            	};
            """)

        #expect(types(s.retypeCandidates(for: "web")) == ["Database", "Queue"])

        try s.changeType(of: "web", to: NodeType(string: "Queue"))
        #expect(try s.exportVGL().contains("node web: Queue \"Web App\""))
    }

    @Test("Given a node at the top level, then types that are only ever details are not offered")
    func aTopLevelNodeIsNotOfferedDetailOnlyTypes() throws {
        let s = try session(
            """
            	node customer: Person "Customer";
            """)

        #expect(types(s.retypeCandidates(for: "customer")) == ["System"])
    }

    @Test("Given a type the containment check rejects, then without ⌥ it is refused, and with ⌥ applied and reported")
    func aMisfittingTypeNeedsTheBreak() throws {
        let s = try session(
            """
            	group ibs: System "Internet Banking" {
            		node web: Container "Web App";
            	};
            """)

        #expect(throws: VError.self) { try s.changeType(of: "web", to: NodeType(string: "Component")) }
        #expect(try s.exportVGL().contains("node web: Container \"Web App\""))

        try s.changeType(of: "web", to: NodeType(string: "Component"), notationBreak: .permitted)

        #expect(try s.exportVGL().contains("node web: Component \"Web App\""))
        #expect(GenericQualityChecks.containment(graph: s.origin).map { $0.target } == [.node("web")])
    }

    @Test("Given a detailed node, then only types allowed where it sits whose detailing admits every detail are offered")
    func aDetailedNodeIsOfferedTypesThatKeepItsDetails() throws {
        let s = try session(
            """
            	group ibs: System "Internet Banking" {
            		group web: Container "Web App" {
            			group layer "Layer" {
            				node ctl: Component "Controller";
            			};
            		};
            	};
            """)

        #expect(types(s.retypeCandidates(for: "web")) == ["Queue"])

        try s.changeType(of: "web", to: NodeType(string: "Queue"))

        let exported = try s.exportVGL()
        #expect(exported.contains("group web: Queue \"Web App\""))
        #expect(exported.contains("node ctl: Component \"Controller\""))
        #expect(GenericQualityChecks.containment(graph: s.origin).isEmpty)
    }

    @Test("Given a detailed node retyped with ⌥ to a type that does not admit its details, then those details are reported")
    func aDetailedNodeRetypedWithTheBreakReportsItsMisfits() throws {
        let s = try session(
            """
            	group ibs: System "Internet Banking" {
            		group web: Container "Web App" {
            			node ctl: Component "Controller";
            			node api: Component "API";
            		};
            	};
            """)

        #expect(throws: VError.self) { try s.changeType(of: "web", to: NodeType(string: "Database")) }

        try s.changeType(of: "web", to: NodeType(string: "Database"), notationBreak: .permitted)

        #expect(try s.exportVGL().contains("group web: Database \"Web App\""))
        #expect(GenericQualityChecks.containment(graph: s.origin).map { $0.target } == [.node("ctl"), .node("api")])
    }

    /// A detailed node is a node: the menu retypes it by node type, never by
    /// boundary kind, and ⌥ reaches every other node type.
    @Test("Given a detailed node, then the menu retypes it as a node")
    func theMenuRetypesADetailedNodeAsANode() throws {
        let s = try session(
            """
            	group ibs: System "Internet Banking" {
            		group web: Container "Web App" {
            			node ctl: Component "Controller";
            		};
            	};
            """)

        #expect(EditorCore.menu(for: "web", in: s).first { $0.id == .changeType }?.enabled == true)

        let (step, _) = EditorCore.begin(.changeType, on: "web", forcingChoice: false, in: s)
        #expect(
            step
                == .perform(
                    .changeType(node: "web", to: NodeType(string: "Queue"), edgeTypes: [], notationBreak: .forbidden)))

        let (asked, opened) = EditorCore.begin(.changeType, on: "web", forcingChoice: true, in: s)
        guard case .ask(_, let options) = asked, let hatch = options.last else {
            Issue.record("expected a question, got \(asked)")
            return
        }
        #expect(options.map { $0.isBreak } == [false, true])
        let (broken, _) = EditorCore.next(after: hatch, in: opened, session: s)
        guard case .ask(_, let anyType) = broken else {
            Issue.record("expected the node types, got \(broken)")
            return
        }
        #expect(anyType.map { $0.id } == ["Person", "System", "Database", "Queue", "Component", "Table"])
    }

    @Test("Given a detailed node, then a boundary kind is refused rather than replacing its node type")
    func aDetailedNodeTakesNoBoundaryKind() throws {
        let s = try makeTestSession(
            vgl: Self.notation.replacingOccurrences(of: "}\n", with: "\tgroup type: Boundary\n}\n")
                + """
                vgraph g: Arch "G" {
                	group sys: System "Internet Banking" {
                		node web: Container "Web App";
                	};
                }
                """)

        #expect(throws: VError.self) { try s.changeType(of: "sys", to: GroupType(string: "Boundary")) }
        #expect(try s.exportVGL().contains("group sys: System \"Internet Banking\""))
    }
}
