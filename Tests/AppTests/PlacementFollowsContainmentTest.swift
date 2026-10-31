import EditorCore
import Testing
import VGraph

@testable import App

/// ADR-0032's one rule for placement: without ⌥, adding and moving a node offer
/// only what the containment check accepts; with ⌥ anything goes.
@Suite("Placement follows containment")
struct PlacementFollowsContainmentTest {

    private static let vgl = """
        vnotation Arch {
        	node type: Person [nodeStyle: roundedBox]
        	node type: System [nodeStyle: roundedBox, detailedBy: (Container, Database)]
        	node type: Container [nodeStyle: roundedBox, detailedBy: (Component)]
        	node type: Database [nodeStyle: roundedBox]
        	node type: Component [nodeStyle: roundedBox]
        	node type: Process [nodeStyle: roundedBox, detailedBy: (Process)]
        }

        vgraph g: Arch "G" {
        	node user: Person "User";
        	node web: Container "Web";
        	group misc "Misc" {
        		node mail: Component "Mail";
        	};
        	group ibs: System "Internet Banking" {
        		node db: Database "DB";
        		group api: Container "API" {
        			node auth: Component "Auth";
        		};
        	};
        }
        """

    private func session() throws -> TestSession {
        try makeTestSession(vgl: Self.vgl)
    }

    private func offered(on target: String, forcingChoice: Bool, in s: TestSession) -> Set<String> {
        let (step, _) = EditorCore.begin(.addNode, on: target, forcingChoice: forcingChoice, in: s)
        guard case .ask(_, let options) = step else {
            Issue.record("expected a question, got \(step)")
            return []
        }
        return Set(options.map(\.id))
    }

    // MARK: - Add node

    @Test("Given a detailed node, when adding a node inside it, then only its detail types are offered")
    func addingInsideADetailedNodeOffersItsDetailTypes() throws {
        let s = try session()

        #expect(offered(on: "ibs", forcingChoice: false, in: s) == ["Container", "Database"])
    }

    @Test("Given a detailed node with one detail type, when adding a node inside it, then that type is made unasked")
    func aSoleDetailTypeIsNotAQuestion() throws {
        let s = try session()

        let (step, _) = EditorCore.begin(.addNode, on: "api", forcingChoice: false, in: s)

        #expect(step == .perform(.addNode(in: "api", ofType: NodeType(string: "Component"), notationBreak: .forbidden)))
    }

    @Test("Given the top level, when adding a node, then types that are only ever details are not offered")
    func addingAtTheTopLevelLeavesOutDetailOnlyTypes() throws {
        let s = try session()

        #expect(offered(on: s.rootGroupId(), forcingChoice: false, in: s) == ["Person", "Process", "System"])
    }

    @Test("Given ⌥, when adding a node, then every type is offered")
    func altOffersEveryType() throws {
        let s = try session()

        #expect(
            offered(on: s.rootGroupId(), forcingChoice: true, in: s)
                == ["Component", "Container", "Database", "Person", "Process", "System"])
    }

    @Test("Given a detailed node whose type has no detail types, then Add node inside it needs ⌥")
    func nothingPlaceableIsANotationBreak() throws {
        let s = try makeTestSession(
            vgl: """
                vnotation Arch {
                	node type: Person [nodeStyle: roundedBox]
                	node type: Container [nodeStyle: roundedBox]
                }

                vgraph g: Arch "G" {
                	group user: Person "User" { node web: Container "Web"; };
                }
                """)

        let plain = EditorCore.menu(for: "user", in: s).first { $0.id == .addNode }
        let withAlt = EditorCore.menu(for: "user", in: s, notationBreak: .permitted).first { $0.id == .addNode }

        #expect(plain?.availability == .forbiddenByNotation)
        #expect(withAlt?.enabled == true)
    }

    @Test("Given a type the detailed node does not list, when adding it inside without ⌥, then it is refused")
    func addingAnUnlistedTypeIsRefused() throws {
        let s = try session()

        #expect(throws: VError.self) { try s.addNode(in: "ibs", ofType: NodeType(string: "Component")) }
        #expect(s.origin.nodes.filter { s.origin.group(of: $0) == Group(rawValue: "ibs") } == [Node("db")])
    }

    @Test("Given a type only ever a detail, when adding it at the top level without ⌥, then it is refused")
    func addingADetailOnlyTypeAtTheTopIsRefused() throws {
        let s = try session()

        #expect(throws: VError.self) { try s.addNode(in: nil, ofType: NodeType(string: "Database")) }
    }

    @Test("Given ⌥, when adding a type the detailed node does not list, then it is added and the check reports it")
    func altAddsAnUnlistedTypeAndTheCheckWarns() throws {
        let s = try session()
        let warnedBefore = Set(GenericQualityChecks.containment(graph: s.origin).map { $0.target })

        try s.addNode(in: "ibs", ofType: NodeType(string: "Component"), notationBreak: .permitted)

        let added = s.origin.nodes.filter { s.origin.group(of: $0) == Group(rawValue: "ibs") && $0.id != "db" }
        #expect(added.count == 1)
        let warnedAfter = Set(GenericQualityChecks.containment(graph: s.origin).map { $0.target })
        #expect(warnedAfter.subtracting(warnedBefore) == Set(added.map { QualityTarget.node($0.id) }))
    }

    @Test("Given ⌥, when adding a node, then the command carries the break")
    func altCarriesTheBreakIntoTheCommand() throws {
        let s = try session()

        let (_, asked) = EditorCore.begin(.addNode, on: s.rootGroupId(), forcingChoice: true, in: s)
        let (step, _) = EditorCore.next(
            after: VCommandOption(id: "Component", title: "Component"), in: asked, session: s)

        #expect(
            step
                == .perform(.addNode(in: s.rootGroupId(), ofType: NodeType(string: "Component"), notationBreak: .permitted)))
    }

    // MARK: - Move

    @Test("Given a type the detailed node does not list, when moving it in, then it is refused")
    func movingInAnUnlistedTypeIsRefused() throws {
        let s = try session()

        #expect(!s.moveDestinations(for: ["auth"]).contains("ibs"))
        #expect(throws: VError.self) { try s.move(["auth"], into: "ibs") }
    }

    @Test("Given ⌥, when moving a type the detailed node does not list, then it moves")
    func altMovesAnUnlistedType() throws {
        let s = try session()

        #expect(s.moveDestinations(for: ["auth"], notationBreak: .permitted).contains("ibs"))
        try s.move(["auth"], into: "ibs", notationBreak: .permitted)

        #expect(s.origin.group(of: Node("auth")) == Group(rawValue: "ibs"))
    }

    @Test("Given a listed detail type, when moving it into the detailed node, then it moves")
    func movingInAListedTypeIsAllowed() throws {
        let s = try session()

        #expect(s.moveDestinations(for: ["web"]).contains("ibs"))
        try s.move(["web"], into: "ibs")

        #expect(s.origin.group(of: Node("web")) == Group(rawValue: "ibs"))
    }

    @Test("Given a type that is only ever a detail, when moving it to the top level, then it is refused")
    func movingADetailOnlyTypeOutIsRefused() throws {
        let s = try session()

        #expect(!s.moveDestinations(for: ["db"]).contains(s.rootGroupId()))
        #expect(throws: VError.self) { try s.move(["db"], into: s.rootGroupId()) }
    }

    @Test("Given a plain group, when moving it into a detailed node, then its members are judged there")
    func aPlainGroupCarriesItsMembersJudgement() throws {
        let s = try session()

        #expect(!s.moveDestinations(for: ["misc"]).contains("ibs"))
        #expect(s.moveDestinations(for: ["misc"], notationBreak: .permitted).contains("ibs"))
    }

    @Test("Given a drag over a detailed node that does not list the cargo's type, then only ⌥ washes it")
    func theDragWashesUnderAltOnly() throws {
        let s = try session()
        let over = Hit(element: "ibs", moveDestination: "ibs", overDiagram: true)
        let pressed = GestureState().handling(
            .press(at: VPoint(x: 0, y: 0), button: 0, isPrimary: true, grab: .element("auth"), shift: false, alt: false, holdable: false),
            holding: Selection(), in: s, hit: { over }, anchor: { _ in VPoint(x: 5, y: 5) }
        ).state

        func pulled(alt: Bool) -> [GestureEffect] {
            pressed.handling(
                .move(to: VPoint(x: 40, y: 0), buttonsHeld: true, alt: alt),
                holding: Selection(), in: s, hit: { over }, anchor: { _ in VPoint(x: 5, y: 5) }
            ).effects
        }

        #expect(pulled(alt: false).contains(.washDropTarget("")))
        #expect(pulled(alt: true).contains(.washDropTarget("ibs")))
    }
}
