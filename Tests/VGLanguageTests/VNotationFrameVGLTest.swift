import Foundation
import Testing

@testable import App
@testable import VGLanguage
@testable import VGraph

/// The frame keys round-trip, and a vnotation writes back only what it
/// declared itself.
@Suite("A vnotation's frame keys in VGL")
struct VNotationFrameVGLTest {

    private func parse(_ source: String) throws -> VGraph {
        try VGraphParser(logger: NoOpLogger()).parse(source: source)
    }

    private func lines(containing marker: String, in vgl: String) -> [String] {
        vgl.split(separator: "\n").map { String($0) }.filter { $0.contains(marker) }
    }

    static let ownTypes = """
        vnotation Work {
        	node type: Project [nodeStyle: roundedBox, detailedBy: (Task), frameDash: "2,5", frameColor: "#123456", frameFill: "#fafafa", frameRadius: 3]
        	node type: Task [nodeStyle: roundedBox]
        	group type: Team [frameDash: "", frameColor: "#aa0000"]
        }

        vgraph plan: Work "Plan" {
        	group launch: Project "Launch" {
        		node write: Task "Write"
        	}
        	group core: Team "Core" {
        		node meet: Task "Meet"
        	}
        }
        """

    @Test("Given a node type with a frame, when exported, then the frame keys are written and reparse to the same text")
    func nodeTypeRoundTrip() throws {
        let first = try VGLExporter().export(graph: parse(Self.ownTypes))

        let project = try #require(lines(containing: "node type: Project", in: first).first)
        #expect(project.contains("frameDash: \"2,5\""))
        #expect(project.contains("frameColor: \"#123456\""))
        #expect(project.contains("frameFill: \"#fafafa\""))
        #expect(project.contains("frameRadius: 3"))
        #expect(try VGLExporter().export(graph: parse(first)) == first)
    }

    @Test("Given a group type with a frame, when exported, then its line carries the keys and reparses to the same text")
    func groupTypeRoundTrip() throws {
        let first = try VGLExporter().export(graph: parse(Self.ownTypes))

        let team = try #require(lines(containing: "group type: Team", in: first).first)
        #expect(team.contains("frameDash: \"\""))
        #expect(team.contains("frameColor: \"#aa0000\""))
        #expect(try VGLExporter().export(graph: parse(first)) == first)
    }

    @Test("Given a vnotation overriding one frame key of an inherited type, when exported, then only that key is written")
    func onlyOwnChangesAreWritten() throws {
        let exported = try VGLExporter().export(
            graph: parse(
                """
                vnotation MyC4 extends C4 {
                	node type: Container [frameDash: "1,1"]
                	group type: Organisation [frameColor: "#00aa00"]
                }

                vgraph g: MyC4 "G" {
                	node p: Person "P"
                }
                """))

        #expect(lines(containing: "node type: Container", in: exported) == ["\tnode type: Container [frameDash: \"1,1\"]"])
        #expect(lines(containing: "group type:", in: exported) == ["\tgroup type: Organisation [frameColor: \"#00aa00\"]"])
    }

    @Test("Given a vnotation that changes no frame, when exported, then no frame key is written")
    func nothingDeclaredNothingWritten() throws {
        let exported = try VGLExporter().export(
            graph: parse(
                """
                vnotation MyC4 extends C4 {
                	group type: Team
                }

                vgraph g: MyC4 "G" {
                	node p: Person "P"
                }
                """))

        #expect(!exported.contains("frame"))
    }

    @Test("Given a declared colour equal to the generic border's light value, when exported, then it is still written")
    func aDeclaredColorIsKeptEvenWhenItMatchesTheDefault() throws {
        let exported = try VGLExporter().export(
            graph: parse(
                """
                vnotation Teams {
                	node type: Member [nodeStyle: roundedBox]
                	group type: Team [frameColor: "#909088"]
                }

                vgraph org: Teams "Org" {
                	node ann: Member "Ann"
                }
                """))

        #expect(lines(containing: "group type: Team", in: exported) == ["\tgroup type: Team [frameColor: \"#909088\"]"])
    }

    @Test(
        "Given an invalid frame value, when parsed, then the error names the key",
        arguments: [
            ("frameDash", "\"foo\""), ("frameDash", "\"4,-2\""), ("frameRadius", "-5"),
            ("frameRadius", "wide"), ("frameColor", "\"zzz\""), ("frameFill", "\"#12\""),
        ])
    func invalidValuesAreRefused(key: String, value: String) {
        let source = """
            vnotation Teams {
            	node type: Member [nodeStyle: roundedBox]
            	group type: Team [\(key): \(value)]
            }

            vgraph org: Teams "Org" {
            	node ann: Member "Ann"
            }
            """
        #expect {
            _ = try parse(source)
        } throws: { error in
            "\(error)".contains(key)
        }
    }

    @Test("Given an unknown key on a group type, when parsed, then it is refused rather than silently dropped")
    func unknownGroupTypeKeysAreRefused() {
        let source = """
            vnotation Teams {
            	node type: Member [nodeStyle: roundedBox]
            	group type: Team [bogus: 1]
            }

            vgraph org: Teams "Org" {
            	node ann: Member "Ann"
            }
            """
        #expect {
            _ = try parse(source)
        } throws: { error in
            "\(error)".contains("bogus")
        }
    }

    @Test("Given frame keys in a vnotation, when highlighted semantically, then nothing is flagged as an error")
    func highlightedWithoutErrors() {
        let html = VGraphParser(logger: NoOpLogger()).semanticHighlightHTML(source: Self.ownTypes)
        // Nothing is flagged only if the document got far enough to be checked: a typo
        // in the same document is.
        let typo = Self.ownTypes.replacingOccurrences(of: "group core: Team", with: "group core: Teem")
        let flagged = VGraphParser(logger: NoOpLogger()).semanticHighlightHTML(source: typo)
        #expect(flagged.contains("<span class=\"vg-error\">Teem</span>"))

        #expect(!html.contains("vg-error"))
    }
}
