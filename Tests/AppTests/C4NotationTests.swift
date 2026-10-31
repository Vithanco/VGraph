import Testing
import VGraph

@testable import App

/// C4 declares its hierarchy and eight same-level relationships (ADR-0032);
/// everything across levels is gained from those.
@Suite("C4 notation")
struct C4NotationTests {

    private static let banking = """
        vgraph banking: C4 "Internet Banking" {
            node customer: Person "Customer";
            node staff: Person "Back Office Staff";
            node mainframe: SoftwareSystem "Mainframe";
            node email: SoftwareSystem "E-mail System";
            group ibs: SoftwareSystem "Internet Banking System" {
                node spa: Container "Single-Page App";
                node web: Container "Web Application";
                node db: Database "Database";
                group api: Container "API Application" {
                    group accounts: Component "Accounts Controller" {
                        node gateway: CodeElement "AccountsGateway";
                        node service: CodeElement "AccountsService";
                    };
                    node signIn: Component "Sign In Controller";
                    node security: Component "Security Component";
                };
            };
        }
        """

    private func offers(_ from: String, _ to: String) throws -> [String] {
        try makeTestSession(vgl: Self.banking).connectCandidates(from: from, to: to).map { $0.id.id }
    }

    @Test("Given two elements on the same level, when connecting them, then the one declared relationship is offered")
    func eachDeclaredRelationshipIsOneOffer() throws {
        #expect(try offers("customer", "staff") == ["interacts_with"])
        #expect(try offers("customer", "mainframe") == ["uses"])
        #expect(try offers("mainframe", "customer") == ["delivers_to"])
        #expect(try offers("mainframe", "email") == ["depends_on"])
        #expect(try offers("web", "spa") == ["communicates_with"])
        #expect(try offers("spa", "db") == ["reads_and_writes"])
        #expect(try offers("signIn", "security") == ["calls"])
        #expect(try offers("gateway", "service") == ["references"])
    }

    @Test("Given an element and a detail at another level, when connecting them, then the relationship it details is offered")
    func detailsGainTheirSystemsRelationship() throws {
        #expect(try offers("customer", "spa") == ["uses"])
        #expect(try offers("customer", "signIn") == ["uses"])
        #expect(try offers("signIn", "mainframe") == ["depends_on"])
        #expect(try offers("signIn", "db") == ["reads_and_writes"])
        #expect(try offers("spa", "signIn") == ["communicates_with"])
        #expect(try offers("gateway", "signIn") == ["calls"])
        #expect(try offers("db", "customer") == ["delivers_to"])
        #expect(try offers("gateway", "db") == ["reads_and_writes"])
    }

    @Test("Given details at both ends on different levels, when connecting them, then nothing is offered")
    func bothEndsDetailedNeedADeclaration() throws {
        #expect(try offers("db", "spa").isEmpty)
    }

    // MARK: - Quality report

    private func report(_ body: String) throws -> QualityReport {
        try makeTestApp().analyzeQuality("vgraph banking: C4 \"Internet Banking\" {\n" + body + "\n}\n")
    }

    @Test("Given every element nested where C4 details it, and connected, then the quality report is clean")
    func aNestedModelIsClean() throws {
        let result = try report(
            """
            group bank: Organisation "Big Bank" {
                node customer: Person "Customer";
                group ibs: SoftwareSystem "Internet Banking System" {
                    node spa: Container "Single-Page App";
                    node db: Database "Database";
                    group api: Container "API Application" {
                        group accounts: Component "Accounts Controller" {
                            node gateway: CodeElement "AccountsGateway";
                        };
                    };
                };
            };
            node mainframe: SoftwareSystem "Mainframe";
            edge customer -> spa "Uses";
            edge spa -> gateway "Makes API calls to";
            edge gateway -> db "Reads from";
            edge gateway -> mainframe "Calls";
            """)

        #expect(result.messages.map { $0.message } == [])
    }

    @Test("Given a Container outside every Software System, then the containment check reports it, and nothing else does")
    func aStrayContainerIsReportedOnce() throws {
        let result = try report(
            """
            node customer: Person "Customer";
            node web: Container "Web App";
            edge customer -> web "Uses";
            """)

        #expect(result.messages.map { $0.target } == [.node("web")])
        #expect(result.messages.first?.message.contains("top level") == true)
    }

    @Test("Given a Component directly inside a Software System, then it is reported as not one of the system's details")
    func aComponentInASystemIsMisplaced() throws {
        let result = try report(
            """
            node customer: Person "Customer";
            group ibs: SoftwareSystem "Internet Banking System" {
                node signIn: Component "Sign In";
            };
            edge customer -> signIn "Uses";
            """)

        #expect(
            result.messages.map { $0.message } == [
                "Component \"Sign In\" is inside SoftwareSystem \"Internet Banking System\", which is detailed by Container and Database"
            ])
    }

    @Test("Given an element with no relationships, then it is reported as an orphan")
    func anOrphanIsReported() throws {
        let result = try report(#"node lonely: SoftwareSystem "Lonely System";"#)

        #expect(
            result.messages.contains {
                $0.target == .node("lonely") && $0.message.contains("\"Lonely System\" has no relationships")
            })
    }

    // MARK: - Removed types

    @Test("Given a boundary group type, then it is unknown: a system or container boundary is a detailed node")
    func boundaryGroupTypesAreGone() throws {
        for type in ["SystemBoundary", "ContainerBoundary", "EnterpriseBoundary"] {
            let result = try report("group b: \(type) \"B\" {\n node p: Person \"P\";\n };\nedge p -> p \"talks to\";")

            #expect(result.messages.map { $0.message } == ["Group \"B\" uses an unknown group type for this notation"])
        }
    }

    @Test("Given an External element type, then it is unknown: being external is not a kind")
    func externalTypesAreGone() throws {
        let result = try report(
            """
            node customer: Person "Customer";
            node mainframe: ExternalSoftwareSystem "Mainframe";
            edge customer -> mainframe "Uses";
            """)

        #expect(!result.errors.isEmpty)
    }
}

/// c4model.com's diagram checklist: every arrow has a label stating its purpose.
@Suite("C4 relationship labels")
struct C4RelationshipLabelTests {

    private func findings(_ edges: String) throws -> [MessageWithSeverity] {
        let vgl = """
            vgraph g: C4 "G" {
                node customer: Person "Customer";
                node mail: SoftwareSystem "E-mail";
                node bank: SoftwareSystem "Bank";
                \(edges)
            }
            """
        return try makeTestApp().analyzeQuality(vgl).messages.filter { $0.message.contains("label") }
    }

    @Test("Given a relationship without a label, then it is reported as a warning on that edge")
    func anUnlabelledRelationshipIsReported() throws {
        let found = try findings("edge customer -> bank;")
        #expect(found.map { $0.severity } == [.warning])
        #expect(found.first?.target == .edge(from: "customer", to: "bank"))
    }

    @Test("Given labelled relationships, then nothing is reported")
    func aLabelledRelationshipIsNotReported() throws {
        #expect(try findings("edge customer -> bank \"Views balances using\"; edge bank -> mail \"Sends e-mail using\";").isEmpty)
    }
}

@Suite("C4 code-level arrows")
struct C4CodeArrowTests {
    @Test("Given an unlabelled code-level reference, then no label is asked for")
    func codeReferencesNeedNoLabel() throws {
        let vgl = """
            vgraph g: C4 "G" {
                node a: CodeElement "A";
                node b: CodeElement "B";
                edge a -> b [arrowhead: "empty"; style: dashed];
            }
            """
        let found = try makeTestApp().analyzeQuality(vgl).messages.filter { $0.message.contains("label") }
        #expect(found.isEmpty)
    }
}
