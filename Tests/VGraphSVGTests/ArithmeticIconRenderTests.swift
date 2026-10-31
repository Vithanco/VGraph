import TestSupport
import Testing
import VGraph
import VGraphSVG

@testable import App

private func path(of icon: String) -> String {
    BuiltinIcons.artwork(for: icon)?.path ?? "<no artwork for \(icon)>"
}

@Suite("Rendered Arithmetic nodes")
struct ArithmeticIconRenderTests {

    private func render(_ body: String) throws -> String {
        try VGraphTestApp().renderGraph("vgraph a: Arithmetic \"A\" {\n\(body)\n}").svg
    }

    @Test("Given plus, minus, times and divide nodes, when rendered, then each draws its own icon and no text")
    func operatorsDrawIcons() throws {
        let svg = try render("node p: Plus; node m: Minus; node t: Times; node d: Divide;")

        for icon in ["plus", "minus", "times", "divide"] {
            #expect(svg.contains(path(of: icon)), "no \(icon) icon")
        }
        for typed in [">+</text>", ">−</text>", ">×</text>", ">:</text>"] {
            #expect(!svg.contains(typed), "\(typed) is still typed")
        }
    }

    @Test("Given an equals node with nothing to compare, when rendered, then it draws the equals icon")
    func anEmptyEqualsDrawsTheEqualsIcon() throws {
        let svg = try render("node eq: Equals;")

        #expect(svg.contains(path(of: "equals")))
        #expect(!svg.contains(">=</text>"))
    }

    @Test("Given an equals node with the literal 3 and nothing to compare, when rendered, then it shows the text \"= 3\"")
    func aLiteralEqualsShowsItsValue() throws {
        #expect(try render("node eq: Equals \"3\";").contains(">= 3</text>"))
    }

    @Test("Given an equals node whose sides both come to 3, when rendered, then it shows the text \"= 3\"")
    func aCorrectEqualsShowsTheValue() throws {
        let svg = try render(
            """
            node one: Number "1"; node two: Number "2"; node op: Plus; node eq: Equals "3";
            edge one -> op: plus_first_operand;
            edge two -> op: plus_second_operand;
            edge op -> eq: plus_result;
            """)

        #expect(svg.contains(">= 3</text>"))
    }

    @Test("Given an equals node whose sides differ, when rendered, then it draws the not-equal icon and no numbers")
    func anIncorrectEqualsDrawsOnlyTheNotEqualIcon() throws {
        let svg = try render(
            """
            node three: Number "3"; node four: Number "4"; node op: Times; node eq: Equals "11";
            edge three -> op: times_first_operand;
            edge four -> op: times_second_operand;
            edge op -> eq: times_result;
            """)

        #expect(svg.contains(path(of: "not-equal")))
        #expect(!svg.contains("≠"))
        #expect(!svg.contains(">12<") && !svg.contains(">11<"))
    }
}
