import App
import Foundation
import Testing
import VGraph
import VGraphMCPTools

@testable import vgraph_mcp

@Suite("ConceptMap Quality Analysis Tests")
struct ConceptMapQualityTests {

    /// Helper: create a VGraphMCPApp for testing
    private func makeApp() -> VGraphMCPApp {
        VGraphMCPApp()
    }

    @Test("Correct counts and ratio for 3 concepts and 2 relations")
    func testCountsAndRatio() throws {
        let vgl = """
            vgraph test: ConceptMap "Test?" {
                node a: Concept "Dog"
                node b: Concept "Cat"
                node c: Concept "Animal"
                node r1: Relation "is a"
                node r2: Relation "likes"
                edge a -> r1
                edge r1 -> c
                edge b -> r2
                edge r2 -> a
            }
            """
        let report = try makeApp().analyzeQuality(vgl)
        let formatted = report.formatted()
        #expect(formatted != nil)
        #expect(formatted!.contains("Concepts: 3, Relations: 2, Ratio: 0.67"))
    }

    @Test("Label length warning for concept with 4+ words")
    func testLabelLengthWarning() throws {
        let vgl = """
            vgraph test: ConceptMap "Test?" {
                node a: Concept "A Very Long Concept Name"
                node b: Concept "Cat"
                node r1: Relation "is a"
                edge a -> r1
                edge r1 -> b
            }
            """
        let report = try makeApp().analyzeQuality(vgl)
        let formatted = report.formatted()
        #expect(formatted != nil)
        #expect(formatted!.contains("Warnings:"))
        #expect(formatted!.contains("A Very Long Concept Name"))
    }

    @Test("No warning for short labels with 1-3 words")
    func testNoWarningForShortLabels() throws {
        let vgl = """
            vgraph test: ConceptMap "Test?" {
                node a: Concept "Dog"
                node b: Concept "Big Cat"
                node c: Concept "Wild Red Fox"
                node d: Concept "Horse"
                node e: Concept "Bird"
                node r1: Relation "likes"
                node r2: Relation "chases"
                node r3: Relation "sees"
                node r4: Relation "follows"
                edge a -> r1
                edge r1 -> b
                edge b -> r2
                edge r2 -> c
                edge c -> r3
                edge r3 -> d
                edge d -> r4
                edge r4 -> e
            }
            """
        let report = try makeApp().analyzeQuality(vgl)
        #expect(report.warnings.isEmpty)
    }

    @Test("EmphasizedConcept is counted as concept")
    func testEmphasizedConceptCounted() throws {
        let vgl = """
            vgraph test: ConceptMap "Test?" {
                node a: Concept "Dog"
                node b: EmphasizedConcept "Cat"
                node r1: Relation "is"
                edge a -> r1
                edge r1 -> b
            }
            """
        let report = try makeApp().analyzeQuality(vgl)
        let formatted = report.formatted()
        #expect(formatted != nil)
        #expect(formatted!.contains("Concepts: 2"))
    }

    @Test("Unconnected concept produces warning")
    func testUnconnectedConceptWarning() throws {
        let vgl = """
            vgraph test: ConceptMap "Test?" {
                node a: Concept "Dog"
                node b: Concept "Cat"
                node orphan: Concept "Orphan"
                node r1: Relation "is"
                edge a -> r1
                edge r1 -> b
            }
            """
        let report = try makeApp().analyzeQuality(vgl)
        let unconnectedWarnings = report.warnings.filter { $0.message.contains("Orphan") }
        #expect(!unconnectedWarnings.isEmpty)
    }

    @Test("Unreused relations with same label and targets produce warning")
    func testUnreusedRelationsWarning() throws {
        let vgl = """
            vgraph test: ConceptMap "Test?" {
                node a: Concept "Dog"
                node b: Concept "Cat"
                node c: Concept "Mammal"
                node r1: Relation "is a"
                node r2: Relation "is a"
                edge a -> r1
                edge r1 -> c
                edge b -> r2
                edge r2 -> c
            }
            """
        let report = try makeApp().analyzeQuality(vgl)
        let unreusedWarnings = report.warnings.filter { $0.message.contains("is a") && $0.message.contains("reusing") }
        #expect(!unreusedWarnings.isEmpty)
    }

    @Test("Well-formed ConceptMap has no warnings or errors")
    func testCleanGraphNoWarnings() throws {
        let vgl = """
            vgraph test: ConceptMap "Test?" {
                node a: Concept "Dog"
                node b: Concept "Cat"
                node c: Concept "Fish"
                node d: Concept "Bird"
                node e: Concept "Animal"
                node r1: Relation "likes"
                node r2: Relation "is a"
                node r3: Relation "chases"
                node r4: Relation "sees"
                edge a -> r1
                edge r1 -> b
                edge b -> r2
                edge r2 -> e
                edge c -> r3
                edge r3 -> d
                edge d -> r4
                edge r4 -> e
            }
            """
        let report = try makeApp().analyzeQuality(vgl)
        #expect(report.isClean)
    }

    // MARK: - Orphan Clusters

    @Test("Two disconnected clusters produce warning")
    func testOrphanClustersWarning() throws {
        let vgl = """
            vgraph test: ConceptMap "Test?" {
                node a: Concept "Dog"
                node b: Concept "Cat"
                node c: Concept "Fish"
                node d: Concept "Bird"
                node e: Concept "Mammal"
                node r1: Relation "likes"
                node r2: Relation "swims with"
                edge a -> r1
                edge r1 -> b
                edge c -> r2
                edge r2 -> d
                edge d -> r2
                edge r2 -> e
            }
            """
        let report = try makeApp().analyzeQuality(vgl)
        let clusterWarnings = report.warnings.filter { $0.message.contains("disconnected clusters") }
        #expect(!clusterWarnings.isEmpty)
    }

    @Test("Single connected graph has no cluster warning")
    func testNoOrphanClusterWarning() throws {
        let vgl = """
            vgraph test: ConceptMap "Test?" {
                node a: Concept "Dog"
                node b: Concept "Cat"
                node c: Concept "Fish"
                node d: Concept "Bird"
                node e: Concept "Animal"
                node r1: Relation "likes"
                node r2: Relation "is a"
                edge a -> r1
                edge r1 -> b
                edge b -> r2
                edge r2 -> e
                edge c -> r1
                edge r1 -> d
                edge d -> r2
            }
            """
        let report = try makeApp().analyzeQuality(vgl)
        let clusterWarnings = report.warnings.filter { $0.message.contains("disconnected clusters") }
        #expect(clusterWarnings.isEmpty)
    }

    // MARK: - Concept Count

    @Test("Too few concepts produces warning")
    func testTooFewConceptsWarning() throws {
        let vgl = """
            vgraph test: ConceptMap "Test?" {
                node a: Concept "Dog"
                node b: Concept "Cat"
                node c: Concept "Bird"
                node r1: Relation "likes"
                edge a -> r1
                edge r1 -> b
                edge b -> r1
                edge r1 -> c
            }
            """
        let report = try makeApp().analyzeQuality(vgl)
        let countWarnings = report.warnings.filter { $0.message.contains("Only") && $0.message.contains("concepts") }
        #expect(!countWarnings.isEmpty)
    }

    @Test("Adequate concept count produces no size warning")
    func testAdequateConceptCount() throws {
        let vgl = """
            vgraph test: ConceptMap "Test?" {
                node a: Concept "Dog"
                node b: Concept "Cat"
                node c: Concept "Fish"
                node d: Concept "Bird"
                node e: Concept "Horse"
                node f: Concept "Animal"
                node g: Concept "Pet"
                node h: Concept "Wild"
                node i: Concept "Farm"
                node j: Concept "Ocean"
                node r1: Relation "is a"
                node r2: Relation "lives in"
                edge a -> r1
                edge r1 -> f
                edge b -> r1
                edge c -> r2
                edge r2 -> j
                edge d -> r1
                edge e -> r1
                edge a -> r2
                edge r2 -> g
                edge h -> r2
                edge r2 -> i
            }
            """
        let report = try makeApp().analyzeQuality(vgl)
        let countWarnings = report.warnings.filter {
            $0.message.contains("concepts") && ($0.message.contains("Only") || $0.message.contains("splitting"))
        }
        #expect(countWarnings.isEmpty)
    }

    @Test("Too many concepts produces warning")
    func testTooManyConceptsWarning() throws {
        // Build a VGL with 26 concepts
        var nodes = ""
        var edges = ""
        for i in 1...26 {
            nodes += "node c\(i): Concept \"C\(i)\"\n"
        }
        nodes += "node r1: Relation \"links\"\n"
        for i in 1...26 {
            edges += "edge c\(i) -> r1\n"
        }
        edges += "edge r1 -> c1\n"

        let vgl = """
            vgraph test: ConceptMap "Test?" {
                \(nodes)
                \(edges)
            }
            """
        let report = try makeApp().analyzeQuality(vgl)
        let countWarnings = report.warnings.filter { $0.message.contains("splitting") }
        #expect(!countWarnings.isEmpty)
    }

    // MARK: - Vague Relations

    @Test("Vague relation label produces warning")
    func testVagueRelationWarning() throws {
        let vgl = """
            vgraph test: ConceptMap "Test?" {
                node a: Concept "Dog"
                node b: Concept "Cat"
                node c: Concept "Fish"
                node d: Concept "Bird"
                node e: Concept "Horse"
                node r1: Relation "relates to"
                node r2: Relation "chases"
                edge a -> r1
                edge r1 -> b
                edge b -> r2
                edge r2 -> c
                edge c -> r2
                edge r2 -> d
                edge d -> r2
                edge r2 -> e
            }
            """
        let report = try makeApp().analyzeQuality(vgl)
        let vagueWarnings = report.warnings.filter { $0.message.contains("too vague") }
        #expect(!vagueWarnings.isEmpty)
        #expect(vagueWarnings[0].message.contains("relates to"))
    }

    @Test("Specific relation label produces no vague warning")
    func testSpecificRelationNoWarning() throws {
        let vgl = """
            vgraph test: ConceptMap "Test?" {
                node a: Concept "Dog"
                node b: Concept "Cat"
                node c: Concept "Fish"
                node d: Concept "Bird"
                node e: Concept "Horse"
                node r1: Relation "chases"
                node r2: Relation "eats"
                node r3: Relation "sees"
                node r4: Relation "follows"
                edge a -> r1
                edge r1 -> b
                edge b -> r2
                edge r2 -> c
                edge c -> r3
                edge r3 -> d
                edge d -> r4
                edge r4 -> e
            }
            """
        let report = try makeApp().analyzeQuality(vgl)
        let vagueWarnings = report.warnings.filter { $0.message.contains("too vague") }
        #expect(vagueWarnings.isEmpty)
    }

    // MARK: - Redundant Propositions

    @Test("Bidirectional propositions between same pair produce warning")
    func testRedundantPropositionsWarning() throws {
        let vgl = """
            vgraph test: ConceptMap "Test?" {
                node a: Concept "Dog"
                node b: Concept "Cat"
                node c: Concept "Fish"
                node d: Concept "Bird"
                node e: Concept "Horse"
                node r1: Relation "chases"
                node r2: Relation "is chased by"
                node r3: Relation "sees"
                node r4: Relation "follows"
                edge a -> r1
                edge r1 -> b
                edge b -> r2
                edge r2 -> a
                edge c -> r3
                edge r3 -> d
                edge d -> r4
                edge r4 -> e
            }
            """
        let report = try makeApp().analyzeQuality(vgl)
        let redundantWarnings = report.warnings.filter { $0.message.contains("both directions") }
        #expect(!redundantWarnings.isEmpty)
    }

    @Test("Unidirectional propositions produce no redundancy warning")
    func testNoRedundantPropositionsWarning() throws {
        let vgl = """
            vgraph test: ConceptMap "Test?" {
                node a: Concept "Dog"
                node b: Concept "Cat"
                node c: Concept "Fish"
                node d: Concept "Bird"
                node e: Concept "Horse"
                node r1: Relation "chases"
                node r2: Relation "eats"
                node r3: Relation "sees"
                node r4: Relation "follows"
                edge a -> r1
                edge r1 -> b
                edge b -> r2
                edge r2 -> c
                edge c -> r3
                edge r3 -> d
                edge d -> r4
                edge r4 -> e
            }
            """
        let report = try makeApp().analyzeQuality(vgl)
        let redundantWarnings = report.warnings.filter { $0.message.contains("both directions") }
        #expect(redundantWarnings.isEmpty)
    }
}
