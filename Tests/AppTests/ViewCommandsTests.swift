import Testing
import VGLanguage
import VGraph

@testable import App

/// A document with one group and one named view that says nothing yet.
private let bank = """
    vgraph demo: ConceptMap "Demo" {
      group bank "Bank" {
        node a: Concept "A";
      }
      node b: Concept "B";
    }

    vview containers "Containers" {
    }
    """

private let bankFoldedInModel = bank.replacingOccurrences(of: "group bank", with: "folded group bank")

private let twoViews = bank + "\nvview context \"Context\" {\n}\n"

private let noViews = """
    vgraph demo: ConceptMap "Demo" {
      group bank "Bank" {
        node a: Concept "A";
      }
      node b: Concept "B";
    }
    """

private let loops = """
    vgraph cld: CLD "Demo" {
      node price: Stock "Price";
      node demand: Stock "Demand";
      edge price -> demand: opposite;
      edge demand -> price: same;
    }

    vview v "V" {
    }
    """

private func session(_ vgl: String) throws -> TestSession { try makeTestSession(vgl: vgl) }

/// What the document itself says, before any view.
private func model(of text: String) -> String {
    text.range(of: "\nvview ").map { String(text[..<$0.lowerBound]) } ?? text
}

private func viewBlock(_ name: String, in text: String) -> String {
    guard let start = text.range(of: "vview \(name)") else { return "" }
    let rest = text[start.lowerBound...]
    guard let end = rest.range(of: "\n}\n") else { return String(rest) }
    return String(rest[..<end.upperBound])
}

@Suite("Presentation goes to the shown view")
struct ViewPresentationTests {

    @Test("Given containers is shown, when bank is folded, then it is folded in the view and the document still shows it open")
    func foldGoesToTheView() throws {
        let s = try session(bank)
        try s.selectView("containers")
        try s.toggleFolding(of: "bank")
        let text = try s.exportVGL()
        #expect(viewBlock("containers", in: text).contains("folded group bank"))
        #expect(!model(of: text).contains("folded group"))
    }

    @Test("Given bank is folded in containers, when asked, then it is folded in that view and open in the default view")
    func isFoldedReadsTheView() throws {
        let s = try session(bank)
        try s.selectView("containers")
        try s.toggleFolding(of: "bank")
        #expect(s.isFolded("bank"))
        try s.selectView(nil)
        #expect(!s.isFolded("bank"))
    }

    @Test("Given containers is shown, when loop markers are chosen, then the view shows them and the document keeps its own")
    func loopMarkersGoToTheView() throws {
        let s = try session(loops)
        let documents = s.loopMarkers()
        try s.selectView("v")
        try s.setLoopMarkers(.none)
        #expect(s.loopMarkers() == LoopMarkers.none)
        try s.selectView(nil)
        #expect(s.loopMarkers() == documents)
    }

    @Test("Given containers is shown, when a layout direction is chosen, then the view shows it and the document keeps its own")
    func layoutDirectionGoesToTheView() throws {
        let s = try session(bank)
        try s.selectView("containers")
        try s.setLayoutDirection(.leftToRight)
        #expect(s.layoutDirection() == .leftToRight)
        try s.selectView(nil)
        #expect(s.layoutDirection() == .topToBottom)
    }

    @Test("Given an Arithmetic document, when the layout direction is read, then it is the notation's left-to-right")
    func layoutDirectionStartsFromTheNotation() throws {
        let s = try session(
            """
            vgraph sums: Arithmetic "Sums" {
              node one: Number "1";
            }
            """)
        #expect(s.layoutDirection() == .leftToRight)
    }

    @Test("Given the default view is shown, when bank is folded, then the document's own fold state changes")
    func defaultViewWritesTheModel() throws {
        let s = try session(bank)
        try s.toggleFolding(of: "bank")
        #expect(model(of: try s.exportVGL()).contains("folded group bank"))
    }

    @Test("Given bank is folded in the document, when it is unfolded and folded again in containers, then the view lists nothing for it")
    func foldingToTheModelsStateRemovesTheOverride() throws {
        let s = try session(bankFoldedInModel)
        try s.selectView("containers")
        try s.toggleFolding(of: "bank")
        #expect(viewBlock("containers", in: try s.exportVGL()).contains("group bank"))
        try s.toggleFolding(of: "bank")
        #expect(!viewBlock("containers", in: try s.exportVGL()).contains("bank"))
    }
}

@Suite("Structure goes to the document, and nothing opens a fold")
struct ViewStructureTests {

    @Test("Given containers is shown, when a node is added, then it is in the document and not in the view")
    func addGoesToTheModel() throws {
        let s = try session(bank)
        try s.selectView("containers")
        let id = try #require(try s.addNode(in: nil, ofType: NodeType(string: "Concept")))
        let text = try s.exportVGL()
        #expect(model(of: text).contains(id))
        #expect(!viewBlock("containers", in: text).contains(id))
    }

    @Test("Given containers is shown, when a node is relabelled, then the document has the new label and the view has no entry")
    func relabelGoesToTheModel() throws {
        let s = try session(bank)
        try s.selectView("containers")
        try s.setLabel(of: "a", to: "Alpha")
        let text = try s.exportVGL()
        #expect(model(of: text).contains("\"Alpha\""))
        #expect(!viewBlock("containers", in: text).contains("Alpha"))
    }

    @Test("Given bank is folded in the document, when a node is added into it, then the node is inside and bank stays folded")
    func addIntoAFoldedGroupKeepsItFolded() throws {
        let s = try session(bankFoldedInModel)
        let id = try #require(try s.addNode(in: "bank", ofType: NodeType(string: "Concept")))
        #expect(s.isFolded("bank"))
        #expect(s.origin.group(of: Node(string: id))?.id.id == "bank")
    }

    @Test("Given bank is folded in the document, when a node is moved into it, then the node is inside and bank stays folded")
    func moveIntoAFoldedGroupKeepsItFolded() throws {
        let s = try session(bankFoldedInModel)
        try s.move(["b"], into: "bank")
        #expect(s.isFolded("bank"))
        #expect(s.origin.group(of: Node("b")) == Group(rawValue: "bank"))
    }

    @Test("Given bank is folded in containers, when a node is added into it, then the node is inside the document's bank and the view still folds it")
    func addIntoAGroupFoldedInTheView() throws {
        let s = try session(bank)
        try s.selectView("containers")
        try s.toggleFolding(of: "bank")
        let id = try #require(try s.addNode(in: "bank", ofType: NodeType(string: "Concept")))
        #expect(s.isFolded("bank"))
        #expect(s.origin.group(of: Node(string: id))?.id.id == "bank")
    }
}

@Suite("Creating, duplicating, relabelling and deleting views")
struct ViewManagementSessionTests {

    @Test("Given no views, when one is created from the label Containers, then it is listed, shown, and named containers")
    func create() throws {
        let s = try session(noViews)
        try s.createView(label: "Containers")
        #expect(s.views() == [ViewDeclaration(name: "containers", label: "Containers")])
        #expect(s.activeView() == "containers")
        #expect(try s.exportVGL().contains("vview containers \"Containers\""))
    }

    @Test("Given no views, when Containers is created twice, then the second is named containers2")
    func createTwice() throws {
        let s = try session(noViews)
        try s.createView(label: "Containers")
        try s.createView(label: "Containers")
        #expect(s.views().map { $0.name } == ["containers", "containers2"])
    }

    @Test("Given a label that makes no name, when a view is created, then it is refused and nothing changes")
    func createRefused() throws {
        let s = try session(noViews)
        #expect(throws: VError.viewLabelRefused(label: "3D")) { try s.createView(label: "3D") }
        #expect(s.views().isEmpty)
        #expect(!s.canUndo)
    }

    @Test("Given a created view, when undo is pressed once, then the view is gone")
    func createIsOneStep() throws {
        let s = try session(noViews)
        try s.createView(label: "Containers")
        _ = try s.undo()
        #expect(s.views().isEmpty)
    }

    @Test("Given a view that folds bank, when it is duplicated as Copy, then the copy folds bank too and is shown")
    func duplicate() throws {
        let s = try session(bank)
        try s.selectView("containers")
        try s.toggleFolding(of: "bank")
        try s.duplicateActiveView(label: "Copy")
        #expect(s.views().map { $0.name } == ["containers", "copy"])
        #expect(s.activeView() == "copy")
        #expect(viewBlock("copy", in: try s.exportVGL()).contains("folded group bank"))
    }

    @Test("Given the default view is shown, when it is duplicated, then it is refused")
    func duplicateDefault() throws {
        let s = try session(bank)
        #expect(throws: VError.defaultViewIsFixed) { try s.duplicateActiveView(label: "Copy") }
    }

    @Test("Given containers, when it is relabelled, then the label changes, the name stays, and one undo restores the label")
    func relabel() throws {
        let s = try session(bank)
        try s.renameView("containers", label: "Boxes")
        #expect(s.views() == [ViewDeclaration(name: "containers", label: "Boxes")])
        _ = try s.undo()
        #expect(s.views() == [ViewDeclaration(name: "containers", label: "Containers")])
    }

    @Test("Given the default view, when it is relabelled or deleted, then it is refused")
    func defaultViewIsFixed() throws {
        let s = try session(bank)
        #expect(throws: VError.defaultViewIsFixed) { try s.renameView(nil, label: "X") }
        #expect(throws: VError.defaultViewIsFixed) { try s.deleteView(nil) }
    }

    @Test("Given a view name the document lacks, when it is relabelled or deleted, then it is refused")
    func unknownViewRefused() throws {
        let s = try session(bank)
        #expect(throws: VError.unknownView("nope", available: ["containers"])) { try s.renameView("nope", label: "X") }
        #expect(throws: VError.unknownView("nope", available: ["containers"])) { try s.deleteView("nope") }
    }

    @Test("Given context is shown, when containers is deleted, then it is gone and context stays shown")
    func deleteOther() throws {
        let s = try session(twoViews)
        try s.selectView("context")
        try s.deleteView("containers")
        #expect(s.views().map { $0.name } == ["context"])
        #expect(s.activeView() == "context")
    }

    @Test("Given containers is shown, when it is deleted, then the default view is shown")
    func deleteShown() throws {
        let s = try session(bank)
        try s.selectView("containers")
        try s.deleteView("containers")
        #expect(s.activeView() == nil)
    }

    @Test("Given a deleted view, when undo is pressed once, then it is back with its values")
    func undoDelete() throws {
        let s = try session(bank)
        try s.selectView("containers")
        try s.toggleFolding(of: "bank")
        try s.deleteView("containers")
        _ = try s.undo()
        #expect(s.views().map { $0.name } == ["containers"])
        #expect(viewBlock("containers", in: try s.exportVGL()).contains("folded group bank"))
    }
}

@Suite("Switching is navigation, and a vanished view falls back")
struct ViewNavigationTests {

    @Test("Given a view, when it is selected, then it is shown, the VGL is unchanged, and there is nothing to undo")
    func selectIsNavigation() throws {
        let s = try session(bank)
        let before = try s.exportVGL()
        try s.selectView("containers")
        #expect(s.activeView() == "containers")
        #expect(try s.exportVGL() == before)
        #expect(!s.canUndo)
    }

    @Test("Given an edit and then a switch, when undo is pressed, then the edit is undone and not the switch")
    func undoSkipsTheSwitch() throws {
        let s = try session(bank)
        try s.setLabel(of: "a", to: "Alpha")
        try s.selectView("containers")
        _ = try s.undo()
        #expect(s.label(of: "a") == "A")
        #expect(s.activeView() == "containers")
    }

    @Test("Given containers is shown, when an unknown view is selected, then it is refused and containers stays shown")
    func selectUnknown() throws {
        let s = try session(bank)
        try s.selectView("containers")
        #expect(throws: VError.unknownView("nope", available: ["containers"])) { try s.selectView("nope") }
        #expect(s.activeView() == "containers")
    }

    @Test("Given containers is shown, when a document is opened, then the default view is shown")
    func openingResets() throws {
        let s = try session(bank)
        try s.selectView("containers")
        try s.replaceDocument(vgl: bank)
        #expect(s.activeView() == nil)
    }

    @Test("Given a created view is shown, when its creation is undone, then the default view is shown")
    func undoFallsBack() throws {
        let s = try session(noViews)
        try s.createView(label: "Containers")
        _ = try s.undo()
        #expect(s.activeView() == nil)
    }

    @Test("Given containers is shown, when the VGL text drops it, then the default view is shown")
    func textEditFallsBack() throws {
        let s = try session(bank)
        try s.selectView("containers")
        try s.textEdited(vgl: noViews)
        #expect(s.activeView() == nil)
    }

    @Test("Given containers is shown and still exists, when an edit is undone, redone or typed, then it stays shown")
    func existingViewStays() throws {
        let s = try session(bank)
        try s.selectView("containers")
        try s.setLabel(of: "a", to: "Alpha")
        _ = try s.undo()
        #expect(s.activeView() == "containers")
        _ = try s.redo()
        #expect(s.activeView() == "containers")
        try s.textEdited(vgl: bank.replacingOccurrences(of: "\"B\"", with: "\"Bee\""))
        #expect(s.activeView() == "containers")
    }

    @Test("Given a labelled and an unlabelled view, when listed, then they come in document order with the missing label as such")
    func listing() throws {
        let s = try session(bank + "\nvview plain {\n}\n")
        #expect(
            s.views() == [
                ViewDeclaration(name: "containers", label: "Containers"), ViewDeclaration(name: "plain", label: nil),
            ])
    }
}
