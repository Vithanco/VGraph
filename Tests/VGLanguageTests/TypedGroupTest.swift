// Full-cycle coverage for the `group <id>: <GroupType> "<label>" { … }` syntax that
// lets a VGL author give a group a type the notation declares.

import Foundation
import Testing

@testable import VGLanguage
@testable import VGraph

private let repoRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()  // VGLanguageTests
    .deletingLastPathComponent()  // Tests
    .deletingLastPathComponent()  // repo root

private let teams = """
    vnotation Teams {
        node type: Member [nodeStyle: roundedBox]
        edge type: helps from: Member to: Member
        group type: Team
    }

    """

private let typedGroupInput =
    teams + """
        vgraph org: Teams "Org" {
            node lead: Member "Lead";
            group core: Team "Core" {
                node ann: Member "Ann";
                node bob: Member "Bob";
            };
            edge lead -> ann "helps";
        }
        """

private let team = GroupType(string: "Team")

@Suite("Typed groups")
struct TypedGroupTest {

    /// The `: <GroupType>` slot parses and attaches the type to the group.
    @Test func parsesGroupType() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: typedGroupInput)

        #expect(graph.groups.count == 1)
        let core = graph.groups[0]
        try graph.ensure(group: core, attribute: Attributes.Group.Id, isSameAs: "core")

        #expect(graph.groupType(of: core) == team)
    }

    /// Export emits the `: <GroupType>` form (not an attribute line) and it survives a
    /// parse → export → parse round-trip.
    @Test func roundTripsGroupType() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: typedGroupInput)

        let exported = try VGLExporter().export(graph: graph)
        #expect(exported.contains("group core: Team"))
        // The computed groupType must not leak as an attribute line.
        #expect(!exported.contains("groupType:"))

        let reparsed = try VGraphParser(logger: NoOpLogger()).parse(source: exported)
        #expect(reparsed.groups.count == 1)
        #expect(reparsed.groupType(of: reparsed.groups[0]) == team)
    }

    // MARK: - A type the notation never registered

    private static let misspelled =
        teams + """
            vgraph org: Teams "Org" {
                group core: Taem "Core" {
                    node ann: Member "Ann";
                };
            }
            """

    @Test func unknownGroupTypeFallsBackToTheUnknownType() throws {
        let graph = try VGraphParser(logger: NoOpLogger()).parse(source: Self.misspelled)

        let type = graph.groupType(of: graph.groups[0])
        #expect(type == GroupType.unknown)
    }

    /// The cost of following the node and edge treatment: the author's word does
    /// not survive, so a re-exported document has lost the typo it needs fixing in.
    @Test func exportWritesTheSyntheticTypeNotTheTypo() throws {
        let graph = try VGraphParser(logger: NoOpLogger()).parse(source: Self.misspelled)

        let exported = try VGLExporter().export(graph: graph)
        #expect(!exported.contains("Taem"))
        #expect(exported.contains(GroupType.unknownPrefix))
    }

    @Test func unknownGroupTypeIsReportedAsAnError() throws {
        let graph = try VGraphParser(logger: NoOpLogger()).parse(source: Self.misspelled)

        let report = Notations.analyzeQuality(graph: graph)
        let errors = report.messages.filter { $0.severity == .error }
        #expect(errors.contains { $0.message.contains("Core") })
    }

    /// The typo is coloured where it was typed, as an unknown *node* type already is.
    @Test func unknownGroupTypeIsColouredInTheSource() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        let html = parser.semanticHighlightHTML(source: Self.misspelled)

        #expect(html.contains("vg-error\">Taem</span>"))
    }

    @Test func registeredGroupTypeIsNotColouredAsAnError() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        let html = parser.semanticHighlightHTML(source: typedGroupInput)

        #expect(html.contains(">Team</span>"))
        #expect(!html.contains("vg-error\">Team</span>"))
    }

    /// An untyped group still parses and carries no group type.
    @Test func untypedGroupHasNoType() throws {
        let source =
            teams + """
                vgraph org: Teams "Org" {
                    group plain "Plain" {
                        node a: Member "A";
                    };
                }
                """
        let graph = try VGraphParser(logger: NoOpLogger()).parse(source: source)
        #expect(graph.groupType(of: graph.groups[0]) == nil)
    }
}

/// C4's Organisation is the group type that carries a style of its own.
@Suite("C4 typed groups")
struct C4TypedGroupTest {
    private let c4TypedGroupInput = """
        vgraph arch: C4 "Architecture" {
            node customer: Person "Customer";
            group bank: Organisation "Big Bank" {
                node staff: Person "Back Office Staff";
            };
            edge customer -> staff "asks";
        }
        """

    /// A typed group resolves its GroupType's registered GroupStyle (fold-as-zoom face).
    @Test func typedGroupResolvesStyle() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: c4TypedGroupInput)
        let bank = graph.groups[0]

        #expect(graph.resolvedGroupStyle(bank) != nil)
    }

    /// The shipped C4 example is a fixed point of `export(parse(·))` (ADR-0010).
    /// C4's boundary carries `borderdash: 8,4`, whose comma the exporter once
    /// left unquoted — the re-parse then stopped at the `8`.
    @Test func c4ExampleIsExportFixedPoint() throws {
        let path = repoRoot.appendingPathComponent("docs/examples/c4-internet-banking.vgl")
        let source = try String(contentsOf: path, encoding: .utf8)

        let first = try VGLExporter().export(graph: VGraphParser(logger: NoOpLogger()).parse(source: source))
        let second = try VGLExporter().export(graph: VGraphParser(logger: NoOpLogger()).parse(source: first))

        #expect(first == second)
    }
}
