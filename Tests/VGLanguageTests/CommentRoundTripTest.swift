// ADR-0010: comments are attributes on the element they stand above (or after,
// on the same line) and are restored in `//` syntax on export.

import Testing

@testable import VGLanguage
@testable import VGraph

@Suite("VGL comment round trip")
struct CommentRoundTripTest {

    private func roundTrip(_ source: String) throws -> String {
        let parser = VGraphParser(logger: NoOpLogger())
        return try VGLExporter().export(graph: parser.parse(source: source))
    }

    // MARK: - Anchors

    @Test func leadingCommentStaysWithItsNode() throws {
        let out = try roundTrip(
            """
            vgraph t: IBIS "T" {
                // The question that started it all
                node q1: Question "Should we rewrite?";
            }
            """)

        #expect(out.contains("// The question that started it all"))
        let commentLine = try #require(lineIndex(of: "// The question", in: out))
        let nodeLine = try #require(lineIndex(of: "node q1", in: out))
        #expect(nodeLine == commentLine + 1)
    }

    @Test func trailingCommentStaysOnTheSameLine() throws {
        let out = try roundTrip(
            """
            vgraph t: IBIS "T" {
                node q1: Question "Should we rewrite?";
                node a1: Answer "Yes, incrementally"; // preferred
            }
            """)

        let line = try #require(out.split(separator: "\n").first { $0.contains("node a1") })
        #expect(line.contains("// preferred"))
    }

    @Test func graphHeaderCommentIsEmittedAboveTheVgraphLine() throws {
        let out = try roundTrip(
            """
            // Decision record for the payments rewrite
            // Owner: Klaus
            vgraph payments: IBIS "Payments" {
                node q1: Question "Should we rewrite?";
            }
            """)

        let header = try #require(lineIndex(of: "// Decision record", in: out))
        let owner = try #require(lineIndex(of: "// Owner: Klaus", in: out))
        let decl = try #require(lineIndex(of: "vgraph payments", in: out))
        #expect(owner == header + 1)
        #expect(decl == owner + 1)
    }

    @Test func groupsAndEdgesKeepTheirComments() throws {
        let out = try roundTrip(
            """
            vgraph t: IBIS "T" {
                node q1: Question "Q";
                node a1: Answer "A";
                // Risks live in their own box
                group risks "Risks" {
                    node a2: Answer "A2";
                }
                // why this edge exists
                edge q1 -> a1;
            }
            """)

        let groupComment = try #require(lineIndex(of: "// Risks live in their own box", in: out))
        let group = try #require(lineIndex(of: "group risks", in: out))
        #expect(group == groupComment + 1)

        let edgeComment = try #require(lineIndex(of: "// why this edge exists", in: out))
        let edge = try #require(lineIndex(of: "edge q1 -> a1", in: out))
        #expect(edge == edgeComment + 1)
    }

    // MARK: - The blank-line rule

    /// The dominant real pattern (see `docs/examples/itsNoLuck.vgl`): a banner, a blank line,
    /// then the statement. The blank must not break the association, and the
    /// blank *inside* the run must survive.
    @Test func sectionBannerSurvivesAcrossABlankLine() throws {
        let out = try roundTrip(
            """
            vgraph t: IBIS "T" {
                // ==========================================
                // TOP LEVEL - Undesirable Effects
                // ==========================================

                // Top row
                node ude1: Question "Suppliers display a less uniform front";
            }
            """)

        let lines = out.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let start = try #require(lines.firstIndex { $0.contains("// ====") })
        #expect(lines[start + 1].contains("// TOP LEVEL"))
        #expect(lines[start + 2].contains("// ===="))
        #expect(lines[start + 3].trimmingWhitespace().isEmpty)  // interior blank kept
        #expect(lines[start + 4].contains("// Top row"))
        #expect(lines[start + 5].contains("node ude1"))
    }

    /// Blank lines at the *edges* of a run are dropped. Without this the blank
    /// line the exporter itself writes before every group would be re-absorbed
    /// and re-emitted, growing the file by one line per save.
    @Test func blankLinesAtTheEdgesOfARunAreTrimmed() throws {
        let out = try roundTrip(
            """
            vgraph t: IBIS "T" {

                // a note

                node q1: Question "Q";
            }
            """)

        let comment = try #require(lineIndex(of: "// a note", in: out))
        let node = try #require(lineIndex(of: "node q1", in: out))
        #expect(node == comment + 1)
    }

    // MARK: - Idempotence (the acceptance bar from ADR-0010)

    @Test func exportIsAFixedPoint() throws {
        let source = """
            // header
            vgraph t: IBIS "T" {
                // ==========================================
                // SECTION
                // ==========================================

                // first
                node q1: Question "Q"; // inline
                node a1: Answer "A";

                // a boxed pair
                group g "G" {
                    // inner
                    node a2: Answer "A2";
                }
                // the link
                edge q1 -> a1;
            }
            """

        let once = try roundTrip(source)
        let twice = try roundTrip(once)
        #expect(once == twice)
    }

    @Test func repeatedExportDoesNotAccumulateBlankLinesBeforeGroups() throws {
        var text = """
            vgraph t: IBIS "T" {
                node q1: Question "Q";
                // about the group
                group g "G" {
                    node a1: Answer "A";
                }
            }
            """
        for _ in 0..<4 { text = try roundTrip(text) }

        let comment = try #require(lineIndex(of: "// about the group", in: text))
        let group = try #require(lineIndex(of: "group g", in: text))
        #expect(group == comment + 1)
    }

    // MARK: - The attribute alias

    @Test func commentAttributeIsAcceptedAndReExportedAsAComment() throws {
        let out = try roundTrip(
            """
            vgraph t: IBIS "T" {
                node q1: Question "Q" [comment: "generated by a tool"];
            }
            """)

        #expect(out.contains("// generated by a tool"))
        let comment = try #require(lineIndex(of: "// generated by a tool", in: out))
        let node = try #require(lineIndex(of: "node q1", in: out))
        #expect(node == comment + 1)
    }

    /// The comment attributes must never reach a generic `[key: value]` emit site.
    @Test func commentsAreNeverEmittedAsAnAttribute() throws {
        let out = try roundTrip(
            """
            // graph note
            vgraph t: IBIS "T" {
                // node note
                node q1: Question "Q" [fontsize: 16]; // trailing note
                node a1: Answer "A";
                // group note
                group g "G" {
                    node a2: Answer "A2";
                }
                // edge note
                edge q1 -> a1;
            }
            """)

        #expect(!out.contains("comment:"))
        #expect(!out.contains("trailingcomment"))
        #expect(out.contains("[fontsize: 16]"))  // ordinary attributes still emitted
    }

    /// A `vnotation` block reconstructs itself from the graph's attributes, and a
    /// comment is one of those — so it has to exclude them for the same reason
    /// the document emitter does, or the header is printed in both places.
    @Test func aVnotationDoesNotRepeatTheDocumentsComment() throws {
        let out = try roundTrip(
            """
            vnotation Custom {
                node type: Thing [nodeStyle: simpleRoundedBox]
                edge type: rel from: Thing to: Thing
            }

            // converted from something older
            vgraph t: Custom "T" {
                node a: Thing "A";
                node b: Thing "B";
                edge a -> b;
            }
            """)

        #expect(out.components(separatedBy: "// converted from something older").count - 1 == 1)
        #expect(!out.contains("comment:"))
    }

    // MARK: - Comments with no element to hold them

    @Test func homelessCommentsAreDropped() throws {
        let out = try roundTrip(
            """
            vgraph t: IBIS "T" {
                node q1: Question "Q";
                // nothing follows me
            }
            // nor me
            """)

        #expect(!out.contains("nothing follows me"))
        #expect(!out.contains("nor me"))
        #expect(out.contains("node q1"))
    }

    /// Dropped, not left unclaimed to drift onto whatever is declared next.
    @Test func aHomelessCommentDoesNotDriftOntoTheNextDeclaration() throws {
        let out = try roundTrip(
            """
            vgraph t: IBIS "T" {
                group a "A" {
                    node q1: Question "Q";
                    // belongs to nothing
                }
                group b "B" {
                    node a1: Answer "A";
                }
            }
            """)

        #expect(!out.contains("belongs to nothing"))
    }

    /// A bare attribute statement has nowhere to keep a comment, so comments
    /// above one fall through to the next real declaration rather than vanishing.
    @Test func commentsAboveABareAttributeFallThroughToTheNextDeclaration() throws {
        let out = try roundTrip(
            """
            vgraph t: IBIS "T" {
                // about the whole diagram
                rankdir: LR;
                node q1: Question "Q";
            }
            """)

        let comment = try #require(lineIndex(of: "// about the whole diagram", in: out))
        let node = try #require(lineIndex(of: "node q1", in: out))
        #expect(node == comment + 1)
    }

    /// If a declaration somehow carries both, the `//` line the user can see wins.
    @Test func aVisibleCommentLineBeatsTheAttributeAlias() throws {
        let out = try roundTrip(
            """
            vgraph t: IBIS "T" {
                // the visible one
                node q1: Question "Q" [comment: "the alias one"];
            }
            """)

        #expect(out.contains("// the visible one"))
        #expect(!out.contains("the alias one"))
    }

    /// A comment set on an edge *type* must not be copied onto every edge of that
    /// type — an element's comments are read from its own attributes, not inherited.
    @Test func anEdgeTypeCommentIsNotRepeatedOntoItsEdges() throws {
        let out = try roundTrip(
            """
            vnotation N extends IBIS {
                edge type: answers  from: Answer  to: Question [comment: "type-level"]
            }
            vgraph t: N "T" {
                node q1: Question "Q";
                node a1: Answer "A";
                node a2: Answer "A2";
                edge a1 -> q1;
                edge a2 -> q1;
            }
            """)

        #expect(!out.contains("// type-level"))
    }

    // MARK: - Deterministic output

    /// Attributes live in a dictionary, so without a deliberate emission order a
    /// document reorders itself between one save and the next.
    @Test func attributeOrderIsStableAcrossReExport() throws {
        let once = try roundTrip(
            """
            vgraph t: IBIS "T" {
                rankdir: LR;
                fontcolor: darkblue;
                labeljust: l;
                node q1: Question "Q" [fontsize: 16, tooltip: "t", alignGroup: g1];
            }
            """)

        #expect(try roundTrip(once) == once)
    }

    // MARK: - Comments are graph data

    @Test func commentsSurviveOnTheParsedGraph() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(
            source: """
                vgraph t: IBIS "T" {
                    // why q1 matters
                    node q1: Question "Q"; // and a trailing note
                }
                """)

        let attrs = graph.getOwnAttributes(node: Node(string: "q1"))
        #expect(attrs[Attributes.Node.comment.id] == "// why q1 matters")
        #expect(attrs[Attributes.Node.trailingComment.id] == "// and a trailing note")
    }

    /// The storage encoding: lines verbatim with their marker, joined by newline,
    /// an empty entry for a blank line kept between two comment blocks.
    @Test func aMultiBlockRunIsStoredAsNewlineJoinedLines() throws {
        let graph = try VGraphParser(logger: NoOpLogger()).parse(
            source: """
                vgraph t: IBIS "T" {
                    // banner
                    //

                    // sub-heading
                    node q1: Question "Q";
                }
                """)

        let stored = graph.getOwnAttributes(node: Node(string: "q1"))[Attributes.Node.comment.id]
        #expect(stored == "// banner\n//\n\n// sub-heading")
    }

    // MARK: - Helpers

    private func lineIndex(of needle: String, in text: String) -> Int? {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .firstIndex { $0.contains(needle) }
    }
}
