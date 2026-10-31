import Testing

@testable import App
@testable import VGraph

/// The engine's containment check (ADR-0032): a detailed node holds only its
/// type's detail types, and a type that is only ever a detail does not stand at
/// the top level.
@Suite("Containment check")
struct ContainmentCheckTest {

    private static let notation = """
        vnotation Arch {
        	node type: Person [nodeStyle: roundedBox]
        	node type: System [nodeStyle: roundedBox, detailedBy: (Container, Database)]
        	node type: Container [nodeStyle: roundedBox, detailedBy: (Component)]
        	node type: Database [nodeStyle: roundedBox]
        	node type: Component [nodeStyle: roundedBox]
        	node type: Process [nodeStyle: roundedBox, detailedBy: (Process)]
        }

        """

    /// Only what the containment check says; other checks (disconnected nodes
    /// and the like) are not under test here.
    private func containmentFindings(_ body: String) throws -> [MessageWithSeverity] {
        let vgl = Self.notation + "vgraph g: Arch \"G\" {\n" + body + "\n}\n"
        return try makeTestApp().analyzeQuality(vgl).messages.filter { $0.message.contains(" detail") || $0.message.contains("top level") }
    }

    @Test("Given a detailed node holding a type it is not detailed by, then the member is reported")
    func aMemberOfTheWrongTypeIsReported() throws {
        let findings = try containmentFindings(
            """
            	group ibs: System "Internet Banking" {
            		node web: Container "Web App";
            		node api: Component "API";
            	};
            """)

        #expect(findings.map { $0.target } == [.node("api")])
        #expect(findings.map { $0.severity } == [.warning])
        #expect(findings.first?.message == "Component \"API\" is inside System \"Internet Banking\", which is detailed by Container and Database")
    }

    @Test("Given plain groups between a detailed node and its members, then they are judged against the detailed node")
    func plainGroupsAreTransparent() throws {
        let findings = try containmentFindings(
            """
            	group ibs: System "Internet Banking" {
            		group front "Front End" {
            			group inner "Inner" {
            				node web: Container "Web App";
            				node api: Component "API";
            			};
            		};
            	};
            """)

        #expect(findings.map { $0.target } == [.node("api")])
    }

    @Test("Given a detailed node inside another, then it is judged by its own node type")
    func aDetailedNodeIsAMemberToo() throws {
        let findings = try containmentFindings(
            """
            	group ibs: System "Internet Banking" {
            		group web: Container "Web App" {
            			node ctl: Component "Controller";
            		};
            		group misplaced: Component "Misplaced" {
            			node inner: Component "Inner";
            		};
            	};
            """)

        #expect(findings.map { $0.target } == [.node("inner"), .node("misplaced")])
    }

    @Test("Given a detail-only type outside every detailed node, then it is reported, even inside a plain group")
    func aDetailOnlyTypeAtTheTopLevelIsReported() throws {
        let findings = try containmentFindings(
            """
            	node customer: Person "Customer";
            	node ibs: System "Internet Banking";
            	node db: Database "Accounts";
            	group bank "Big Bank" {
            		group web: Container "Web App" {
            			node ctl: Component "Controller";
            		};
            	};
            """)

        #expect(findings.map { $0.target } == [.node("db"), .node("web")])
        #expect(findings.map { $0.severity } == [.warning, .warning])
        #expect(findings.first?.message == "Database \"Accounts\" is at the top level, but a Database belongs inside a System")
    }

    @Test("Given a type that details itself, then it may stand at the top level")
    func aSelfDetailingTypeMayStandAtTheTopLevel() throws {
        let findings = try containmentFindings(
            """
            	group order: Process "Handle Order" {
            		node pick: Process "Pick";
            	};
            	node ship: Process "Ship";
            """)

        #expect(findings.isEmpty)
    }

    @Test("Given a notation without detailings, then grouping its nodes reports nothing")
    func aNotationWithoutDetailingsReportsNothingNew() throws {
        let vgl = """
            vgraph g: IBIS "G" {
            	group research "Research" {
            		group methods "Methods" {
            			node q: Question "Which database?";
            		};
            		node a: Answer "Postgres";
            	};
            	node p: Pro "Mature";
            	edge q -> a;
            	edge a -> p;
            }
            """
        let report = try makeTestApp().analyzeQuality(vgl)
        #expect(report.isClean, "\(report.messages.map { $0.message })")
    }

    @Test("Given a node of an unknown type inside a detailed node, then only the unknown type is reported")
    func anUnknownTypeIsNotAlsoAContainmentFinding() throws {
        let findings = try containmentFindings(
            """
            	group ibs: System "Internet Banking" {
            		node web: Contaner "Web App";
            	};
            """)

        #expect(findings.isEmpty)
    }
}
