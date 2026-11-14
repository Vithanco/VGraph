// Pins the exact hover rules for the shapes the renderer tests do not draw:
// a self-loop, parallel edges and a junctor chain in one graph. The rule text
// is order-sensitive, and snapshot diffs are hard to read, so any change to
// how neighbourhoods are gathered shows up here first.

import Testing

@testable import VGLanguage
@testable import VGraph
@testable import VGraphSVG

@Suite("SVGHoverStyles")
struct SVGHoverStylesTests {

    private func rules(_ source: String) throws -> String {
        let graph = try VGraphParser(logger: TestLogger()).parse(source: source)
        return try SVGHoverStyles.rules(graph: graph)
    }

    /// One line per hover scope: the hovered id, then every id it lights up, in
    /// emitted order. Read off the glow rule, which names each target once.
    private func highlights(_ source: String) throws -> [String] {
        try rules(source).split(separator: "\n")
            .filter { $0.contains("drop-shadow") }
            .map { line in
                let selectors = line.prefix { $0 != "{" }.split(separator: ",")
                let hovered = selectors[0].split(separator: "#")[1].prefix { $0 != ":" }
                let lit = selectors.map { $0.split(separator: "#").last ?? "" }
                return "\(hovered): " + lit.joined(separator: " ")
            }
    }

    /// What hovering each element lights besides itself, as a set, with edges
    /// named `from->to` so an expectation reads like the diagram.
    private func neighbourhoods(_ source: String) throws -> [String: Set<String>] {
        let graph = try VGraphParser(logger: TestLogger()).parse(source: source)
        var names: [String: String] = [:]
        for node in graph.nodes { names[SVGElementId.displayNode(node, in: graph)] = node.id }
        for edge in graph.edges { names[SVGElementId.edge(edge.id.id)] = edge.from.id + "->" + edge.to.id }
        var result: [String: Set<String>] = [:]
        for line in try SVGHoverStyles.rules(graph: graph).split(separator: "\n") where line.contains("drop-shadow") {
            let selectors = line.prefix { $0 != "{" }.split(separator: ",")
            let hoveredId = String(selectors[0].split(separator: "#")[1].prefix { $0 != ":" })
            let hovered = names[hoveredId] ?? hoveredId
            let lit = selectors.map { selector in
                let id = String(selector.split(separator: "#").last ?? "")
                return names[id] ?? id
            }
            result[hovered] = Set(lit).subtracting([hovered])
        }
        return result
    }

    /// Two propositions share `carries`, and `offers` makes two more.
    private let conceptMap = """
        vgraph cm: ConceptMap "Propositions" {
            node skill: Concept "Skill"
            node prompt: Concept "Prompt"
            node method: Concept "Method"
            node server: Concept "Server"
            node tool: Concept "Tool"
            node carries: Relation "carries"
            node offers: Relation "offers"
            edge skill -> carries
            edge prompt -> carries
            edge carries -> method
            edge server -> offers
            edge offers -> tool
            edge offers -> prompt
        }
        """

    @Test func aConceptLightsEveryPropositionItIsSubjectOrObjectOf() throws {
        // "Prompt carries Method" and "Server offers Prompt" — not Skill, which
        // carries Method in a proposition of its own, nor Tool.
        #expect(
            try neighbourhoods(conceptMap)["prompt"] == [
                "prompt->carries", "carries", "carries->method", "method",
                "offers->prompt", "offers", "server->offers", "server",
            ])
    }

    @Test func aRelationLightsAllItsPropositions() throws {
        #expect(
            try neighbourhoods(conceptMap)["carries"] == [
                "skill->carries", "skill", "prompt->carries", "prompt", "carries->method", "method",
            ])
    }

    @Test func anEdgeLightsThePropositionsItBelongsTo() throws {
        let hoods = try neighbourhoods(conceptMap)
        #expect(hoods["prompt->carries"] == ["prompt", "carries", "carries->method", "method"])
        #expect(
            hoods["carries->method"] == [
                "carries", "method", "skill->carries", "skill", "prompt->carries", "prompt",
            ])
    }

    /// `7 − 4 = 2 + 1`, with the 4 also used in `4 × 3 = 12`.
    private let equations = """
        vgraph eq: Arithmetic "Both sides" {
            node seven: Number "7"
            node four: Number "4"
            node two: Number "2"
            node one: Number "1"
            node three: Number "3"
            node minus: Minus
            node plus: Plus
            node times: Times
            node eq: Equals "3"
            node eqTimes: Equals "12"
            edge seven -> minus: minus_first_operand
            edge four -> minus: minus_second_operand
            edge two -> plus: plus_first_operand
            edge one -> plus: plus_second_operand
            edge minus -> eq: minus_result
            edge plus -> eq: plus_result
            edge four -> times: times_first_operand
            edge three -> times: times_second_operand
            edge times -> eqTimes: times_result
        }
        """

    @Test func aNumberLightsTheWholeEquationAndNoOtherThatSharesANumber() throws {
        let wholeEquation: Set<String> = [
            "seven->minus", "minus", "four->minus", "four", "minus->eq", "eq",
            "plus->eq", "plus", "two->plus", "two", "one->plus", "one",
        ]
        #expect(try neighbourhoods(equations)["seven"] == wholeEquation)
    }

    @Test func eachNodeInARowCarriesTheWalkByItsOwnValue() throws {
        let source = """
            vnotation Chain {
                node type: Thing [nodeStyle: simpleRoundedBox]
                node type: Verb [nodeStyle: bareText, addsToNeighborhood: onward]
                node type: Joint [nodeStyle: circle, addsToNeighborhood: all]
                edge type: thing_verb from: Thing to: Verb
                edge type: verb_joint from: Verb to: Joint
                edge type: thing_joint from: Thing to: Joint
                edge type: joint_thing from: Joint to: Thing
            }

            vgraph g: Chain "In a row" {
                node a: Thing "A"
                node b: Thing "B"
                node c: Thing "C"
                node v: Verb "v"
                node j: Joint
                edge a -> v
                edge v -> j
                edge b -> j
                edge j -> c
            }
            """
        let hoods = try neighbourhoods(source)
        let everything: Set<String> = ["a->v", "a", "v", "v->j", "j", "b->j", "b", "j->c", "c"]
        #expect(hoods["a"] == everything.subtracting(["a"]))
        #expect(hoods["b"] == everything.subtracting(["b"]))
    }

    @Test func graphWithoutEdgesHasNoRules() throws {
        let source = """
            vgraph cld: CLD "Lonely" {
                node a: Stock "A"
            }
            """
        #expect(try rules(source) == "")
    }

    @Test func selfLoopAndParallelEdgesPinned() throws {
        let source = """
            vgraph cld: CLD "Edge shapes" {
                node a: Stock "A"
                node b: Stock "B"
                edge a -> b: same
                edge a -> b: opposite
                edge b -> b: same
            }
            """
        #expect(
            try highlights(source) == [
                "node-a: edge-100002 edge-100003 node-b",
                "node-b: edge-100002 edge-100003 edge-100004 node-a",
                "edge-100002: node-a node-b",
                "edge-100003: node-a node-b",
                "edge-100004: node-b",
            ])
    }

    @Test func junctorChainPinned() throws {
        let source = """
            vgraph crt: CRT "Junctor chain" {
                node a: Changeable "Cause A"
                node c: Changeable "Cause C"
                node j: AndJunctor
                node b: UndesirableEffect "Effect B"
                edge a -> j
                edge c -> j
                edge j -> b
            }
            """
        #expect(
            try highlights(source) == [
                "node-a: edge-100002 edge-100003 edge-100004 node-j node-c node-b",
                "node-c: edge-100003 edge-100002 edge-100004 node-j node-a node-b",
                "node-j: edge-100002 edge-100003 edge-100004 node-a node-c node-b",
                "node-b: edge-100004 edge-100002 edge-100003 node-j node-a node-c",
                "edge-100002: edge-100002 edge-100003 edge-100004 node-a node-j node-c node-b",
                "edge-100003: edge-100002 edge-100003 edge-100004 node-c node-j node-a node-b",
                "edge-100004: edge-100002 edge-100003 edge-100004 node-j node-a node-c node-b",
            ])
    }
}
