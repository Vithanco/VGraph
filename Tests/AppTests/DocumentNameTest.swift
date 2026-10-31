//
//  DocumentNameTest.swift
//  VGraph
//
//  The name an opened file leaves behind, which the two saves then reuse.
//
//  There is no file *handle* behind the [[File menu]] — the browser gives none
//  a page may write back through — so "save" is always a download and the name
//  is the only trace an open leaves (CONTEXT.md [[File menu]]).
//
//  Pure string rules, and they were in the wasm target where no Swift test
//  could reach them.
//

import EditorCore
import Testing

struct DocumentNameTest {
    /// A [[Diagram as document]] is saved as `.vithanco.svg` to say so, and
    /// reopening one must not grow the name each time.
    @Test("Reopening a saved diagram recovers the name it was saved under")
    func aSavedDiagramRoundTrips() {
        #expect(EditorCore.documentName(fromFile: "climate.vithanco.svg") == "climate")
    }

    /// The browser owns its `" (1)"` — `download` proposes a name and no more —
    /// and it reads `.svg` alone as the extension, so on a second save the
    /// suffix lands in the *middle* of `.vithanco.svg`. Reopening that must
    /// recover a name that still says which document it is, suffix and all.
    @Test("A collision suffix is lifted back out of the middle of the name")
    func aCollisionSuffixSurvivesTheExtension() {
        #expect(EditorCore.documentName(fromFile: "climate.vithanco (1).svg") == "climate (1)")
    }

    /// A `.vgl` file keeps its own formatting and is not a
    /// [[Diagram as document]], so there is no `.vithanco` to lift off — and its
    /// collision suffix sits where the browser normally puts one.
    @Test("A plain VGL file keeps its stem, suffix and all")
    func aPlainVGLFileKeepsItsStem() {
        #expect(EditorCore.documentName(fromFile: "climate.vgl") == "climate")
        #expect(EditorCore.documentName(fromFile: "climate (2).vgl") == "climate (2)")
    }

    /// Only `" (n)"` counts, and only with the space: a name that merely ends in
    /// a bracket is a name, and stripping it would rename the user's document
    /// behind their back.
    @Test("A name that merely ends in a bracket is left alone")
    func bracketsThatAreNotACollisionSuffixSurvive() {
        #expect(EditorCore.documentName(fromFile: "notes(draft).vgl") == "notes(draft)")
        #expect(EditorCore.documentName(fromFile: "(1).vgl") == "(1)")
    }

    // MARK: - What an opened file turns out to be

    /// Refusing an SVG we did not write beats loading its markup into the editor
    /// and leaving the parser to complain about it. The message names the file,
    /// because the user picked it and needs to know which one was wrong.
    @Test("An SVG carrying no VGL is refused by name")
    func aForeignSVGIsRefused() {
        let opened = EditorCore.opened(
            "<svg xmlns=\"http://www.w3.org/2000/svg\"><rect/></svg>",
            named: "chart.svg", embeddedVGL: nil)

        #expect(
            opened == .refused("chart.svg carries no VGL — only diagrams saved by VGraph do"))
    }

    /// Ours is recognised by what it carries, not by its extension — so an SVG
    /// with the VGL inside opens as the document it is.
    @Test("An SVG carrying VGL opens as that VGL")
    func ourOwnSVGOpens() {
        let vgl = "vgraph d: IBIS \"D\" { node q: Question \"Q\"; }"

        #expect(
            EditorCore.opened("<svg>…</svg>", named: "d.vithanco.svg", embeddedVGL: vgl)
                == .vgl(vgl))
    }

    /// Anything that is not SVG is taken as VGL and handed to the parser, which
    /// is the one that gets to complain.
    @Test("A plain file is taken as VGL")
    func aPlainFileIsVGL() {
        #expect(
            EditorCore.opened("vgraph d: IBIS \"D\" { }", named: "d.vgl", embeddedVGL: nil)
                == .vgl("vgraph d: IBIS \"D\" { }"))
    }

    /// An XML prologue and leading whitespace are both ordinary in a file
    /// written by another tool, and neither should get past the refusal.
    @Test("An SVG is recognised behind whitespace and an XML prologue")
    func svgIsRecognisedBehindItsPrologue() {
        for text in ["  \n<svg/>", "<?xml version=\"1.0\"?><svg/>", "\t<?xml ?>"] {
            #expect(
                EditorCore.opened(text, named: "x.svg", embeddedVGL: nil)
                    == .refused("x.svg carries no VGL — only diagrams saved by VGraph do"),
                "not recognised as SVG: \(text)")
        }
    }

    /// The picker can hand back nothing at all, and both saves still need a
    /// filename.
    @Test("A file with no name falls back to the default")
    func anEmptyNameFallsBack() {
        #expect(EditorCore.documentName(fromFile: "") == EditorCore.defaultDocumentName)
    }
}
