import Testing

@testable import App
@testable import VGraph

/// ADR-0032: bounds count every pair of a type, so decomposing never silently
/// switches a rule off.
@Suite("Bounds over gained pairs")
struct BoundsOverGainedPairsTest {

    private func notation(uses bounds: String) -> String {
        """
        vnotation Arch {
        	node type: Person [nodeStyle: roundedBox]
        	node type: System [nodeStyle: roundedBox, detailedBy: (Container)]
        	node type: Container [nodeStyle: roundedBox, detailedBy: (Component)]
        	node type: Component [nodeStyle: roundedBox]
        	edge type: uses from: Person to: System [\(bounds)]
        }

        """
    }

    /// Only what the bound check says.
    private func boundFindings(_ bounds: String, _ body: String) throws -> [MessageWithSeverity] {
        let vgl = notation(uses: bounds) + "vgraph g: Arch \"G\" {\n" + body + "\n}\n"
        return try makeTestApp().analyzeQuality(vgl).messages.filter { $0.message.contains("\"uses\"") }
    }

    @Test("Given outDegreeMax 1, then a Person using one system and another system's container is reported")
    func outDegreeCountsAGainedPair() throws {
        let findings = try boundFindings(
            "outDegreeMax: 1",
            """
            	node p: Person "Customer";
            	node mail: System "Mail";
            	group ibs: System "Internet Banking" {
            		node web: Container "Web App";
            	};
            	edge p -> mail;
            	edge p -> web;
            """)

        #expect(findings.map { $0.target } == [.edge(from: "p", to: "web")])
        #expect(findings.map { $0.severity } == [.error])
    }

    /// Before decomposing, two people using the system broke the bound; after,
    /// they use two of its containers and still do.
    @Test("Given inDegreeMax 1, then two people using different details of one system are reported")
    func inDegreeCountsAtTheDetailedNode() throws {
        let findings = try boundFindings(
            "inDegreeMax: 1",
            """
            	node p1: Person "Customer";
            	node p2: Person "Clerk";
            	group ibs: System "Internet Banking" {
            		node web: Container "Web App";
            		group api: Container "API" {
            			node ctl: Component "Controller";
            		};
            	};
            	edge p1 -> web;
            	edge p2 -> ctl;
            """)

        #expect(findings.map { $0.target } == [.edge(from: "p2", to: "ctl")])
        #expect(findings.first?.message == "Too many \"uses\" edges entering \"Internet Banking\" — at most 1 allowed")
    }

    @Test("Given inDegreeMin 1, then a detailed node is satisfied by an edge to one of its details")
    func aMinimumIsMetThroughADetail() throws {
        let findings = try boundFindings(
            "inDegreeMin: 1",
            """
            	node p: Person "Customer";
            	group ibs: System "Internet Banking" {
            		node web: Container "Web App";
            	};
            	edge p -> web;
            """)

        #expect(findings.isEmpty, "\(findings.map { $0.message })")
    }

    @Test("Given inDegreeMin 1, then a detailed node none of whose details is used is reported")
    func aMinimumStillHoldsAfterDecomposing() throws {
        let findings = try boundFindings(
            "inDegreeMin: 1",
            """
            	group ibs: System "Internet Banking" {
            		node web: Container "Web App";
            	};
            """)

        #expect(findings.map { $0.target } == [.node("ibs")])
        #expect(findings.map { $0.severity } == [.warning])
        #expect(findings.first?.message == "\"Internet Banking\" needs at least 1 \"uses\" incoming edge — has 0")
    }

    @Test("Given samePairMax 1, then two edges on one gained pair are reported")
    func pairMultiplicityCountsAGainedPair() throws {
        let findings = try boundFindings(
            "samePairMax: 1",
            """
            	node p: Person "Customer";
            	group ibs: System "Internet Banking" {
            		node web: Container "Web App";
            	};
            	edge p -> web "logs in";
            	edge p -> web "pays";
            """)

        #expect(findings.map { $0.severity } == [.error])
        #expect(findings.first?.message == "Too many \"uses\" edges between \"Customer\" and \"Internet Banking\" — at most 1 allowed")
    }

    /// Folded, the system shows one bundle of two: the pair is the system's.
    @Test("Given samePairMax 1, then edges to two details of one system count as one pair")
    func pairMultiplicityCountsAtTheDetailedNode() throws {
        let findings = try boundFindings(
            "samePairMax: 1",
            """
            	node p: Person "Customer";
            	group ibs: System "Internet Banking" {
            		node web: Container "Web App";
            		node app: Container "Mobile App";
            	};
            	edge p -> web;
            	edge p -> app;
            """)

        #expect(findings.map { $0.target } == [.edge(from: "p", to: "app")])
    }

    /// A Person is the declared end, so it counts for itself wherever it stands.
    @Test("Given samePairMax 1, then edges to two different systems are separate pairs")
    func differentSystemsAreDifferentPairs() throws {
        let findings = try boundFindings(
            "samePairMax: 1",
            """
            	node p: Person "Customer";
            	group ibs: System "Internet Banking" {
            		node web: Container "Web App";
            	};
            	group crm: System "CRM" {
            		node desk: Container "Help Desk";
            	};
            	edge p -> web;
            	edge p -> desk;
            """)

        #expect(findings.isEmpty, "\(findings.map { $0.message })")
    }

    // MARK: - What commands offer

    /// The check and the offer read one bound (ADR-0011).
    @Test("Given outDegreeMax 1 spent on a container, then connecting the Person to another system is not offered")
    func aBoundSpentOnAGainedPairClosesTheDeclaredOne() throws {
        let s = try makeTestSession(
            vgl: notation(uses: "outDegreeMax: 1") + """
                vgraph g: Arch "G" {
                	node p: Person "Customer";
                	node mail: System "Mail";
                	group ibs: System "Internet Banking" {
                		node web: Container "Web App";
                	};
                	edge p -> web;
                }
                """)

        #expect(!s.connectTargets(from: "p").contains("mail"))
        #expect(s.connectTargets(from: "p", notationBreak: .permitted).contains("mail"))
    }

    @Test("Given inDegreeMax 1 spent on one detail, then connecting to another detail of that system is not offered")
    func anInDegreeSpentOnADetailClosesTheOthers() throws {
        let s = try makeTestSession(
            vgl: notation(uses: "inDegreeMax: 1") + """
                vgraph g: Arch "G" {
                	node p1: Person "Customer";
                	node p2: Person "Clerk";
                	node mail: System "Mail";
                	group ibs: System "Internet Banking" {
                		node web: Container "Web App";
                		node app: Container "Mobile App";
                	};
                	edge p1 -> web;
                }
                """)

        #expect(s.connectTargets(from: "p2") == ["mail"])
    }

    @Test("Given samePairMax 1, then a second detail of a system the Person already uses is not offered")
    func aPairSpentOnADetailClosesTheOthers() throws {
        let s = try makeTestSession(
            vgl: notation(uses: "samePairMax: 1") + """
                vgraph g: Arch "G" {
                	node p: Person "Customer";
                	group ibs: System "Internet Banking" {
                		node web: Container "Web App";
                		node app: Container "Mobile App";
                	};
                	group crm: System "CRM" {
                		node desk: Container "Help Desk";
                	};
                	edge p -> web;
                }
                """)

        #expect(s.connectTargets(from: "p") == ["desk"])
    }
}
