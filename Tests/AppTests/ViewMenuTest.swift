import EditorCore
import Testing
import VGLanguage
import VGraph

@testable import App

private let bank = """
    vgraph demo: ConceptMap "Demo" {
      node a: Concept "A";
    }

    vview context "System Context" {
    }

    vview containers "Containers" {
    }

    vview plain {
    }
    """

private let noViews = """
    vgraph demo: ConceptMap "Demo" {
      node a: Concept "A";
    }
    """

private func session(_ vgl: String) throws -> TestSession { try makeTestSession(vgl: vgl) }

@Suite("The view picker")
struct ViewPickerTest {

    @Test("Given a document without views, then the only option is Default view and it is selected")
    func onlyDefault() throws {
        #expect(
            EditorCore.viewOptions(in: try session(noViews)) == [
                ViewOption(name: nil, title: "Default view", isSelected: true)
            ])
    }

    @Test("Given views, then the options are Default view and then each view by label, or by name when it has none")
    func labelsOrNames() throws {
        let titles = EditorCore.viewOptions(in: try session(bank)).map { $0.title }
        #expect(titles == ["Default view", "System Context", "Containers", "plain"])
    }

    @Test("Given containers is shown, then it is the selected option")
    func selection() throws {
        let s = try session(bank)
        try s.selectView("containers")
        let selected = EditorCore.viewOptions(in: s).filter { $0.isSelected }
        #expect(selected.map { $0.name } == ["containers"])
    }
}

@Suite("The View menu")
struct ViewMenuRowsTest {
    private func rows(_ s: TestSession) -> String {
        EditorCore.viewMenu(in: s)
            .map { "\($0.id.raw) | \($0.title) | \($0.enabled ? "enabled" : "greyed")" }
            .joined(separator: "\n")
    }

    @Test("Given the default view is shown, then New view is enabled and the other three rows are greyed")
    func defaultView() throws {
        #expect(
            rows(try session(bank)) == """
                newView | New view… | enabled
                duplicateView | Duplicate view… | greyed
                renameView | Rename view… | greyed
                deleteView | Delete view | greyed
                """)
    }

    @Test("Given a view is shown, then all four rows are enabled")
    func aView() throws {
        let s = try session(bank)
        try s.selectView("containers")
        #expect(
            rows(s) == """
                newView | New view… | enabled
                duplicateView | Duplicate view… | enabled
                renameView | Rename view… | enabled
                deleteView | Delete view | enabled
                """)
    }
}

@Suite("View conversations")
struct ViewConversationTest {

    @Test("Given New view, then it asks for a label and the answer creates the view")
    func newView() throws {
        let s = try session(bank)
        let (step, opened) = EditorCore.begin(.newView, on: "", forcingChoice: false, in: s)
        #expect(step == .askText(prompt: "New view", initial: ""))
        let (answered, _) = EditorCore.next(afterText: "Deployment", in: opened)
        #expect(answered == .perform(.createView(label: "Deployment")))
    }

    @Test("Given a label the session refuses, then the field is asked again with what was typed")
    func refusedLabelAsksAgain() throws {
        let s = try session(bank)
        let (_, opened) = EditorCore.begin(.newView, on: "", forcingChoice: false, in: s)
        var refusal: VError?
        do { try s.createView(label: "  ") } catch { refusal = error }
        let step = EditorCore.next(afterRefusing: try #require(refusal), typed: "  ", in: opened)
        #expect(step == .askText(prompt: "New view", initial: "  "))
    }

    @Test("Given containers is shown, then Duplicate view asks for a label and the answer duplicates it")
    func duplicate() throws {
        let s = try session(bank)
        try s.selectView("containers")
        let (step, opened) = EditorCore.begin(.duplicateView, on: "containers", forcingChoice: false, in: s)
        #expect(step == .askText(prompt: "Duplicate view", initial: ""))
        let (answered, _) = EditorCore.next(afterText: "Copy", in: opened)
        #expect(answered == .perform(.duplicateView(label: "Copy")))
    }

    @Test("Given containers, then Rename view starts from its current label and the answer renames it")
    func rename() throws {
        let s = try session(bank)
        let (step, opened) = EditorCore.begin(.renameView, on: "containers", forcingChoice: false, in: s)
        #expect(step == .askText(prompt: "Rename view", initial: "Containers"))
        let (answered, _) = EditorCore.next(afterText: "Boxes", in: opened)
        #expect(answered == .perform(.renameView(name: "containers", label: "Boxes")))
    }

    @Test("Given containers, then Delete view asks to confirm: Delete deletes and Cancel does nothing")
    func delete() throws {
        let s = try session(bank)
        let (step, opened) = EditorCore.begin(.deleteView, on: "containers", forcingChoice: false, in: s)
        guard case .ask(_, let options) = step else {
            Issue.record("expected a question, got \(step)")
            return
        }
        #expect(options.map { $0.title } == ["Delete", "Cancel"])
        let (confirmed, _) = EditorCore.next(after: options[0], in: opened, session: s)
        #expect(confirmed == .perform(.deleteView(name: "containers")))
        let (cancelled, _) = EditorCore.next(after: options[1], in: opened, session: s)
        #expect(cancelled == .dismiss)
    }
}

@Suite("Layout direction on the canvas menu")
struct LayoutDirectionConversationTest {

    @Test("Given the canvas, then Layout direction asks the four directions and the answer sets it")
    func asksFourDirections() throws {
        let s = try session(noViews)
        let (step, opened) = EditorCore.begin(.layoutDirection, on: s.rootGroupId(), forcingChoice: false, in: s)
        guard case .ask(_, let options) = step else {
            Issue.record("expected a question, got \(step)")
            return
        }
        #expect(options.count == 4)
        let right = try #require(options.first { $0.id == LayoutDirection.leftToRight.value })
        let (answered, _) = EditorCore.next(after: right, in: opened, session: s)
        #expect(answered == .perform(.setLayoutDirection(.leftToRight)))
    }
}

@Suite("The view the status line names")
struct ShownViewTest {
    @Test("Given the default view, then nothing is named")
    func defaultIsUnnamed() throws {
        let shown = EditorCore.shownView(in: EditorCore.viewOptions(in: try session(bank)))
        #expect(shown.name == "")
        #expect(shown.title == "")
        #expect(EditorCore.statusLine("Rendered OK", viewTitle: shown.title) == "Rendered OK")
    }

    @Test("Given a labelled view is shown, then the status line names it by its label")
    func labelledView() throws {
        let s = try session(bank)
        try s.selectView("containers")
        let shown = EditorCore.shownView(in: EditorCore.viewOptions(in: s))
        #expect(shown.name == "containers")
        #expect(shown.title == "Containers")
        #expect(
            EditorCore.statusLine("Rendered OK", viewTitle: shown.title) == "Rendered OK — View: Containers")
    }

    @Test("Given a view without a label is shown, then it is named by its name")
    func unlabelledView() throws {
        let s = try session(bank)
        try s.selectView("plain")
        let shown = EditorCore.shownView(in: EditorCore.viewOptions(in: s))
        #expect(shown.name == "plain")
        #expect(shown.title == "plain")
    }
}
