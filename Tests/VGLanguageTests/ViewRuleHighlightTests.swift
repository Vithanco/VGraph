import Testing

@testable import App
@testable import VGLanguage
@testable import VGraph

private func banking(_ rules: String) -> String {
    """
    vnotation Banking extends C4 {
        group type: Zone
    }

    vgraph banking: Banking "Internet Banking" {
        node customer: Person "Customer";
        group ibs: Zone "Internet Banking System" {
            node web: Container "Web";
            node api: Container "API";
        }
        edge customer -> web;
        edge web -> api;
    }

    vview v {
    \(rules)
    }
    """
}

private func stripTags(_ html: String) -> String {
    var out = ""
    var inTag = false
    for c in html {
        if c == "<" {
            inTag = true
        } else if c == ">" {
            inTag = false
        } else if !inTag {
            out.append(c)
        }
    }
    return out.replacingOccurrences(of: "&lt;", with: "<").replacingOccurrences(of: "&gt;", with: ">")
        .replacingOccurrences(of: "&amp;", with: "&")
}

private func semantic(_ source: String) -> String {
    VGraphParser(logger: NoOpLogger()).semanticHighlightHTML(source: source)
}

private func keyword(_ word: String) -> String { "<span class=\"vg-kw\">\(word)</span>" }

@Suite("View rules in the highlighter")
struct ViewRuleHighlightTests {

    @Test("Given include node customer, web downstream 1, when highlighted semantically, then include and downstream are keywords")
    func includeAndDownstream() {
        let html = semantic(banking("include node customer, web downstream 1;"))
        #expect(html.contains(keyword("include")))
        #expect(html.contains(keyword("downstream")))
    }

    @Test("Given exclude group type: Zone, when highlighted semantically, then exclude and type are keywords")
    func excludeAndType() {
        let html = semantic(banking("exclude group type: Zone;"))
        #expect(html.contains(keyword("exclude")))
        #expect(html.contains(keyword("type")))
    }

    @Test("Given expand 2, when highlighted semantically, then expand is a keyword and 2 a number")
    func expandAndItsNumber() {
        let html = semantic(banking("include node web;\nexpand 2;"))
        #expect(html.contains(keyword("expand")))
        #expect(html.contains("<span class=\"vg-num\">2</span>"))
    }

    @Test("Given a node named include, when highlighted semantically, then it is not a keyword")
    func aNodeMayBeCalledInclude() {
        let html = semantic(
            """
            vgraph demo: ConceptMap "D" {
              node include: Concept "Include";
            }
            """)
        #expect(!html.contains(keyword("include")))
    }

    @Test("Given any view rule, when highlighted, then the source comes back verbatim")
    func sourceIsKept() {
        let source = banking("include node web downstream 1;\nexclude group type: Zone;\nexpand 2;")
        let parser = VGraphParser(logger: NoOpLogger())
        #expect(stripTags(parser.semanticHighlightHTML(source: source)) == source)
        #expect(stripTags(parser.lexicalHighlightHTML(source: source)) == source)
    }

    @Test("Given include node nothere, when highlighted semantically, then nothere is marked as an error with a tooltip")
    func missingNodeIsMarked() {
        let html = semantic(banking("include node nothere;"))
        #expect(html.contains("<span class=\"vg-error\" title=\"not in the model\">nothere</span>"), "\(html)")
    }

    @Test("Given exclude group nowhere, when highlighted semantically, then nowhere is marked as an error")
    func missingGroupIsMarked() {
        let html = semantic(banking("exclude group nowhere;"))
        #expect(html.contains("<span class=\"vg-error\" title=\"not in the model\">nowhere</span>"))
    }

    @Test("Given include node web, with web existing, then web is not marked")
    func existingNameIsNotMarked() {
        let html = semantic(banking("include node web;\ninclude group ibs;"))
        #expect(!html.contains("vg-error"))
    }

    @Test("Given include node ibs, where ibs is a group, then ibs is marked, since it is the wrong kind")
    func wrongKindIsMarked() {
        let html = semantic(banking("include node ibs;"))
        #expect(html.contains("<span class=\"vg-error\" title=\"not in the model\">ibs</span>"))
    }

    @Test("Given node ghost [fontsize: 16] in a view, when highlighted semantically, then ghost is marked")
    func attributeStatementsAreChecked() {
        let html = semantic(banking("node ghost [fontsize: 16];"))
        #expect(html.contains("<span class=\"vg-error\" title=\"not in the model\">ghost</span>"))
    }

    @Test("Given include node type: Nope, when highlighted semantically, then Nope is marked as an unknown type")
    func unknownTypeIsMarked() {
        let html = semantic(banking("include node type: Nope;"))
        #expect(html.contains("<span class=\"vg-error\">Nope</span>"))
    }

    @Test("Given a document that does not parse, when highlighted semantically, then no name is marked and the source comes back verbatim")
    func nothingIsMarkedWithoutAParse() {
        let source = banking("include node nothere;\ninclude;")
        let html = semantic(source)
        #expect(!html.contains("not in the model"))
        #expect(stripTags(html) == source)
    }
}
