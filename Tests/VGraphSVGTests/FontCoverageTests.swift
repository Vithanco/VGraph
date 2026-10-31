import Foundation
import TestSupport
import Testing
import VGraph
import VGraphSVG

@testable import App

/// Reads which characters a TrueType file has a glyph for (its `cmap` table).
/// The PNG path draws only what the bundled DM Sans can: a missing character is an empty space.
private enum DMSans {

    static func weights() -> [Int: Set<UInt32>] {
        Dictionary(uniqueKeysWithValues: [400, 500, 600, 700].map { ($0, characters(weight: $0)) })
    }

    private static func characters(weight: Int) -> Set<UInt32> {
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        guard let data = try? Data(contentsOf: repo.appendingPathComponent("fonts/DMSans-\(weight).ttf")) else {
            return []
        }
        func u16(_ at: Int) -> Int { Int(data[at]) << 8 | Int(data[at + 1]) }
        func u32(_ at: Int) -> Int { u16(at) << 16 | u16(at + 2) }

        guard
            let cmap = (0..<u16(4)).map({ 12 + $0 * 16 }).first(where: {
                String(decoding: data[$0..<$0 + 4], as: UTF8.self) == "cmap"
            })
        else { return [] }
        let table = u32(cmap + 8)

        var found = Set<UInt32>()
        for record in 0..<u16(table + 2) {
            let sub = table + u32(table + 4 + record * 8 + 4)
            switch u16(sub) {
            case 4:
                let segments = u16(sub + 6) / 2
                let ends = sub + 14
                let starts = ends + segments * 2 + 2
                let deltas = starts + segments * 2
                let offsets = deltas + segments * 2
                for segment in 0..<segments {
                    let (start, end) = (u16(starts + segment * 2), u16(ends + segment * 2))
                    guard end != 0xFFFF else { continue }
                    for code in start...end {
                        var glyph: Int
                        if u16(offsets + segment * 2) == 0 {
                            glyph = code + u16(deltas + segment * 2)
                        } else {
                            glyph = u16(offsets + segment * 2 + u16(offsets + segment * 2) + (code - start) * 2)
                            if glyph != 0 { glyph += u16(deltas + segment * 2) }
                        }
                        if glyph & 0xFFFF != 0 { found.insert(UInt32(code)) }
                    }
                }
            case 12:
                for group in 0..<u32(sub + 12) {
                    let at = sub + 16 + group * 12
                    for code in u32(at)...u32(at + 4) { found.insert(UInt32(code)) }
                }
            default: break
            }
        }
        return found
    }

    /// Characters in `text` the face of `weight` has no glyph for.
    static func missing(in text: String, weight: Int, faces: [Int: Set<UInt32>]) -> Set<Character> {
        let face = faces[weight] ?? []
        return Set(text.filter { !$0.isWhitespace && !($0.unicodeScalars.allSatisfy { face.contains($0.value) }) })
    }
}

private func writtenText(in svg: String) -> [(text: String, weight: Int)] {
    let regex = try! NSRegularExpression(pattern: #"<text([^>]*)>([^<]*)</text>"#)
    return regex.matches(in: svg, range: NSRange(svg.startIndex..., in: svg)).map { match in
        let attributes = String(svg[Range(match.range(at: 1), in: svg)!])
        let text = String(svg[Range(match.range(at: 2), in: svg)!])
            .replacingOccurrences(of: "&amp;", with: "&").replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">").replacingOccurrences(of: "&quot;", with: "\"")
        let weight =
            attributes.range(of: #"font-weight="(\d+)""#, options: .regularExpression)
            .flatMap { Int(attributes[$0].filter(\.isNumber)) } ?? 400
        return (text, weight)
    }
}

@Suite("Text the PNG path can draw")
struct FontCoverageTests {

    private let faces = DMSans.weights()

    @Test("Given every built-in notation rendered, when the text in its node type badges is collected, then every character exists in DM Sans")
    func nodeTypeBadgesNeedNoMissingCharacters() throws {
        let app = VGraphTestApp()
        var missing: [String: Set<Character>] = [:]
        for (name, entry) in NotationRegistry.entries {
            let graph = try VGraph().defineStandardAttributes().placing(entry.content, in: .builtin)
            let nodes = graph.nodeTypes.enumerated().map { "node n\($0.offset): \($0.element.description) \"A\";" }
            let svg = try app.renderGraph("vgraph g: \(name) \"T\" {\n\(nodes.joined(separator: "\n"))\n}").svg
            for (text, weight) in writtenText(in: svg) {
                let lacking = DMSans.missing(in: text, weight: weight, faces: faces)
                if !lacking.isEmpty { missing[name, default: []].formUnion(lacking) }
            }
        }
        #expect(!faces[700]!.isEmpty, "the DM Sans character table could not be read")
        #expect(missing.isEmpty, "characters DM Sans lacks: \(missing)")
    }

    @Test(
        "Given the Right-and-Wrong Arithmetic example rendered, when the text in its operator and equals nodes is collected, then every character exists in DM Sans"
    )
    func arithmeticNeedsNoMissingCharacters() throws {
        let svg = try VGraphTestApp().renderGraph(
            """
            vgraph a: Arithmetic "Right and Wrong" {
                node two: Number "2"; node five: Number "5"; node three: Number "3"; node four: Number "4";
                node plusOp: Plus; node timesOp: Times; node minusOp: Minus; node divideOp: Divide;
                node eqPlus: Equals "7"; node eqTimes: Equals "11"; node eqMinus: Equals "5"; node eqDivide: Equals "7";
                edge two -> plusOp: plus_first_operand; edge five -> plusOp: plus_second_operand;
                edge plusOp -> eqPlus: plus_result;
                edge three -> timesOp: times_first_operand; edge four -> timesOp: times_second_operand;
                edge timesOp -> eqTimes: times_result;
                edge five -> minusOp: minus_first_operand; edge two -> minusOp: minus_second_operand;
                edge minusOp -> eqMinus: minus_result;
                edge four -> divideOp: divide_first_operand; edge two -> divideOp: divide_second_operand;
                edge divideOp -> eqDivide: divide_result;
            }
            """
        ).svg

        var missing = Set<Character>()
        for (text, weight) in writtenText(in: svg) {
            missing.formUnion(DMSans.missing(in: text, weight: weight, faces: faces))
        }
        #expect(!faces[700]!.isEmpty, "the DM Sans character table could not be read")
        #expect(missing.isEmpty, "characters DM Sans lacks: \(missing.sorted())")
    }

    @Test("Given text containing ≠, when checked against DM Sans, then the check reports ≠ as missing")
    func theCheckSeesAMissingCharacter() {
        #expect(!faces[700]!.isEmpty, "the DM Sans character table could not be read")
        #expect(DMSans.missing(in: "2 ≠ 3", weight: 700, faces: faces) == ["≠"])
    }
}
