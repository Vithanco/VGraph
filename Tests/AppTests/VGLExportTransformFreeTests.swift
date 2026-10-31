// VGL is the document format: it is serialised from the OriginGraph, never from a
// graph the display pipeline has touched. `exportDocument` always obeyed that, but
// `exportToVGL` — the `vgraph vgl` formatter — routed through `exportGraph` and so
// serialised transform output into the user's file. DOT keeps its transforms
// (`DotExport`): it is a render target, downstream of the pipeline, not a document.
//
// Marking every derived attribute as display was considered instead and rejected:
// `width`/`height`/`shape` are equally derived yet authorable, so no category can
// be complete. The boundary is the only place the rule can actually hold.

import Testing
import VGLanguage
import VGraph

@testable import App

@Suite("VGL export is transform-free")
struct VGLExportTransformFreeTests {

    /// `BoundaryChromeStep` flattens a typed group's `GroupStyle` into loose
    /// `Attributes.Group.*` so the renderer need not know about `GroupType`. That
    /// derived face is re-derivable from `: Organisation`, and the formatter used to
    /// write it back as three authored attribute lines on every typed group.
    @Test func typedGroupExportsWithoutDerivedChrome() throws {
        let source = """
            vgraph banking: C4 "Banking" {
                group bank: Organisation "Big Bank" {
                    node customer: Person "Customer";
                };
            }
            """
        let vgl = try makeTestApp().exportToVGL(source)

        #expect(vgl.contains("group bank: Organisation"))  // the authored type survives…

        // The exporter lowercases attribute names, hence `vglKey` rather than literals.
        let chrome = [
            Attributes.Group.borderDash.asDefinition.vglKey,
            Attributes.Group.borderColor.asDefinition.vglKey,
            Attributes.Group.backgroundColor.asDefinition.vglKey,
            Attributes.Group.cornerRadius.asDefinition.vglKey,
        ]
        for key in chrome {
            #expect(!vgl.contains(key), "\(key) leaked into exported VGL")  // …its derived face does not
        }
    }

    /// `exportGraph` applies the transforms, so handing it the document exporter is
    /// the mistake this suite exists for. Both exporters share `ForExportAGraph`, so
    /// the type system cannot forbid it — `VGLExporter` refuses at runtime instead.
    @Test func exportGraphRefusesTheDocumentExporter() throws {
        #expect(throws: VError.self) {
            try makeTestApp().exportGraph(
                """
                vgraph demo: ConceptMap "Demo" {
                    node a: Concept "A";
                }
                """, using: VGLExporter())
        }
    }

    /// The formatter is idempotent: whatever it writes must parse back to the same
    /// document, so nothing a transform stamped can become authored input next time.
    @Test func theFormatterIsAFixedPoint() throws {
        let app = makeTestApp()
        let once = try app.exportToVGL(
            """
            vgraph banking: C4 "Banking" {
                group bank: Organisation "Big Bank" {
                    node customer: Person "Customer";
                };
                folded group ops "Operations" {
                    node run: Container "Runtime";
                };
            }
            """)

        #expect(try app.exportToVGL(once) == once)
    }
}
