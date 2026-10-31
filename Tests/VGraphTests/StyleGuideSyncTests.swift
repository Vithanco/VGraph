import Foundation
import Testing

@testable import VGraph

/// The renderer does not read `docs/design/`, so every hex lives twice. This holds
/// the Swift side to the guide: a colour changed in one place only fails here.
struct StyleGuideSyncTests {

    private static let guide: String = {
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = repo.appendingPathComponent("docs/design/Diagram Style Guide.html")
        return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }()

    static func matches(_ pattern: String, in text: String) -> [[String]] {
        let regex = try! NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).map { match in
            (0..<match.numberOfRanges).map { String(text[Range(match.range(at: $0), in: text)!]) }
        }
    }

    static func block(after opener: String) -> String {
        guard let start = guide.range(of: opener), let end = guide.range(of: "}", range: start.upperBound..<guide.endIndex)
        else { return "" }
        return String(guide[start.upperBound..<end.lowerBound])
    }

    static func cssVars(_ block: String) -> [String: String] {
        Dictionary(
            matches(#"(--[a-z0-9-]+):\s*(#[0-9a-fA-F]{6})"#, in: block).map { ($0[1], $0[2].lowercased()) },
            uniquingKeysWith: { first, _ in first })
    }

    /// Light → dark pairs from `CHROME_DARK` and the page's CSS variables, with
    /// every disagreement kept so Rule 1 can be checked on the guide itself.
    private static let guideDark: [String: Set<String>] = {
        let light = cssVars(block(after: ":root {"))
        let dark = cssVars(block(after: "[data-theme=\"dark\"] {"))
        let fromCSS = light.compactMap { name, hex in dark[name].map { (hex, $0) } }
        let fromChrome = matches(#"'(#[0-9a-fA-F]{6})':\s*'(#[0-9a-fA-F]{6})'"#, in: block(after: "const CHROME_DARK = {"))
            .map { ($0[1].lowercased(), $0[2].lowercased()) }
        return Dictionary(grouping: fromCSS + fromChrome) { $0.0 }.mapValues { Set($0.map { $0.1 }) }
    }()

    /// `const IBIS_TYPES = [ … ]` and single-type `const CM_TYPE = { … }` alike.
    private static let guideTypes: [String: (String, String, String)] = {
        var types: [String: (String, String, String)] = [:]
        for declaration in matches(#"const ([A-Z_]+) *= *(\[.*?\];|\{[^}]*\};)"#, in: guide) {
            let triple = #"name:\s*'([^']+)'[^}]*?fill:\s*'(#\w+)',\s*border:\s*'(#\w+)',\s*text:\s*'(#\w+)'"#
            for type in matches(triple, in: declaration[2]) {
                types["\(declaration[1]).\(type[1])"] = (type[2].lowercased(), type[3].lowercased(), type[4].lowercased())
            }
        }
        return types
    }()

    @Test func theGuideIsReadable() {
        #expect(!Self.guide.isEmpty)
        #expect(Self.guideDark.count > 20)
        #expect(Self.guideTypes.count > 30)
    }

    /// Key Rule 1, on the guide: a light hex has one dark hex. White and black
    /// are the README's exceptions.
    @Test func theGuideKeysDarkModeOnTheLightHex() {
        for (light, darks) in Self.guideDark where !["#ffffff", "#000000"].contains(light) {
            #expect(darks.count == 1, "Guide maps \(light) to \(darks.sorted())")
        }
    }

    @Test func chromeTokensMatchTheGuide() {
        let tokens: [SemanticColor] = [
            .page, .edgeEndFill, .edge, .edgeBold, .junctor, .ink, .ink2, .ink3, .groupFill, .groupBorder,
            .groupText, .groupNestedFill, .groupStack, .pillBg, .pillText, .loopIndicator,
            .ghostPillFill, .ghostPillText, .foldedBadgeFill, .linkBadgeFill,
        ]
        for token in tokens {
            let darks = Self.guideDark[token.lightHex.lowercased()]
            #expect(darks == [token.darkHex.lowercased()], "\(token) — guide says \(darks?.sorted() ?? [])")
        }
    }

    private typealias Triple = (SemanticColor, SemanticColor, SemanticColor)

    /// Every guide node type, by `<CONST>.<name>`. A type added to the guide fails
    /// `everyGuideTypeIsMapped` until it is mapped here.
    private static let mapped: [String: Triple] = {
        typealias CRT = Notations.CurrentRealityTree
        typealias IBIS = Notations.Ibis
        typealias CM = Notations.ConceptMap
        typealias CLD = Notations.CausalLoopDiagram
        typealias BBS = Notations.Bbs
        typealias ADT = Notations.ADTree
        typealias DT = Notations.DecisionTree
        typealias IM = Notations.ImpactMapping
        typealias EC = Notations.EvaporatingCloud
        typealias GT = Notations.GoalTree
        typealias PRT = Notations.PrerequisiteTree
        typealias FRT = Notations.FutureRealityTree
        return [
            "CRT_TYPES.Undesirable Effect": (CRT.udeFill, CRT.udeBorder, CRT.udeText),
            "CRT_TYPES.Given": (CRT.givFill, CRT.givBorder, CRT.givText),
            "CRT_TYPES.Intermediate Effect": (CRT.imeFill, CRT.imeBorder, CRT.imeText),
            "CRT_TYPES.Changeable": (CRT.chgFill, CRT.chgBorder, CRT.chgText),
            "IBIS_TYPES.Question": (IBIS.questionFill, IBIS.questionBorder, IBIS.questionText),
            "IBIS_TYPES.Answer": (IBIS.answerFill, IBIS.answerBorder, IBIS.answerText),
            "IBIS_TYPES.Pro": (IBIS.proFill, IBIS.proBorder, IBIS.proText),
            "IBIS_TYPES.Con": (IBIS.conFill, IBIS.conBorder, IBIS.conText),
            "CM_TYPE.Concept": (CM.conceptFill, CM.conceptBorder, CM.conceptText),
            "CLD_TYPE.Stock": (CLD.stockFill, CLD.stockBorder, CLD.stockText),
            "BBS_TYPES.Enabler": (BBS.enFill, BBS.enBorder, BBS.enText),
            "BBS_TYPES.Business Change": (BBS.bcFill, BBS.bcBorder, BBS.bcText),
            "BBS_TYPES.Benefit": (BBS.benFill, BBS.benBorder, BBS.benText),
            "BBS_TYPES.Investment Objective": (BBS.ioFill, BBS.ioBorder, BBS.ioText),
            "ADT_TYPES.Attack": (ADT.attackFill, ADT.attackBorder, ADT.attackText),
            "ADT_TYPES.Defense": (ADT.defenseFill, ADT.defenseBorder, ADT.defenseText),
            "DT_TYPES.Decision Point": (DT.dpFill, DT.dpBorder, DT.dpText),
            "DT_TYPES.Choice": (DT.chFill, DT.chBorder, DT.chText),
            "DT_TYPES.Outcome": (DT.outFill, DT.outBorder, DT.outText),
            "IM_TYPES.Goal": (IM.goalFill, IM.goalBorder, IM.goalText),
            "IM_TYPES.Actor": (IM.actorFill, IM.actorBorder, IM.actorText),
            "IM_TYPES.Impact": (IM.impactFill, IM.impactBorder, IM.impactText),
            "IM_TYPES.Deliverable": (IM.delFill, IM.delBorder, IM.delText),
            "EC_NEW_TYPES.Common Objective": (EC.objFill, EC.objBorder, EC.objText),
            "EC_NEW_TYPES.Solution": (EC.solFill, EC.solBorder, EC.solText),
            "EC_NEW_TYPES.Need": (EC.needFill, EC.needBorder, EC.needText),
            "EC_NEW_TYPES.Want": (EC.wantFill, EC.wantBorder, EC.wantText),
            "EC_NEW_TYPES.Assumption": (EC.asmFill, EC.asmBorder, EC.asmText),
            "GT_TYPES.Necessary Condition": (GT.ncFill, GT.ncBorder, GT.ncText),
            "GT_TYPES.Critical Success Factor": (GT.csfFill, GT.csfBorder, GT.csfText),
            "GT_TYPES.Goal": (GT.goalFill, GT.goalBorder, GT.goalText),
            "PRT_TYPES.Objective": (PRT.objFill, PRT.objBorder, PRT.objText),
            "PRT_TYPES.Intermediate Objective": (PRT.ioFill, PRT.ioBorder, PRT.ioText),
            "PRT_TYPES.Obstacle": (PRT.obsFill, PRT.obsBorder, PRT.obsText),
            "FRT_EXTRA.Desirable Effect": (FRT.deFill, FRT.deBorder, FRT.deText),
            "ANNOTATION.Annotation": (.annotationFill, .annotationBorder, .annotationText),
            "WARNING.Warning": (.warningFill, .warningBorder, .warningText),
        ]
    }()

    @Test func everyGuideTypeIsMapped() {
        #expect(Set(Self.guideTypes.keys) == Set(Self.mapped.keys))
    }

    @Test func notationPalettesMatchTheGuide() {
        for (key, (fill, border, text)) in Self.mapped {
            guard let expected = Self.guideTypes[key] else { continue }
            #expect(fill.lightHex.lowercased() == expected.0, "\(key) fill")
            #expect(border.lightHex.lowercased() == expected.1, "\(key) border")
            #expect(text.lightHex.lowercased() == expected.2, "\(key) text")
        }
    }
}

extension StyleGuideSyncTests {

    @Suite("The style guide's icons")
    struct Icons {

        private struct Master: Equatable {
            let viewBox: [Double]
            let path: String
        }

        private static let guideIcons: [String: (master: Master, names: [String])] = {
            let table = StyleGuideSyncTests.matches(#"const ICONS = \{(.*?)\n\};"#, in: StyleGuideSyncTests.guide).first?[1] ?? ""
            let entry =
                #"'([^']+)':\s*\{\s*kind:\s*'\w+',\s*viewBox:\s*'([^']+)',\s*d:\s*'([^']+)',\s*names:\s*\[([^\]]*)\]\s*\}"#
            return Dictionary(
                StyleGuideSyncTests.matches(entry, in: table).map { icon in
                    let master = Master(viewBox: icon[2].split(separator: " ").compactMap { Double($0) }, path: icon[3])
                    let names = StyleGuideSyncTests.matches(#"'([^']+)'"#, in: icon[4]).map { $0[1] }
                    return (icon[1], (master, names))
                },
                uniquingKeysWith: { first, _ in first })
        }()

        @Test("Given the design system's ICONS table, when read, then it holds the same artworks (viewBox and path) as the built-in icons")
        func theDesignSystemDrawsWhatShips() {
            #expect(!Self.guideIcons.isEmpty, "the design system has no icons table in the new shape")
            for (artwork, entry) in Self.guideIcons {
                for name in entry.names {
                    let shipped = BuiltinIcons.artwork(for: name).map {
                        Master(viewBox: [$0.minX, $0.minY, $0.width, $0.height], path: $0.path)
                    }
                    #expect(shipped == entry.master, "\(name) differs from the design system's \(artwork)")
                }
            }
        }

        @Test("Given the design system's ICONS table, when read, then it maps the same icon names to the same artworks as the built-in icons")
        func theDesignSystemMapsWhatShips() {
            let guideNames = Self.guideIcons.values.flatMap { $0.names }
            #expect(Set(guideNames) == Set(BuiltinIcons.names))
            #expect(guideNames.count == Set(guideNames).count, "an icon name appears under two artworks")
            let guideGroups = Set(Self.guideIcons.values.map { Set($0.names) })
            let shippedGroups = Set(
                Dictionary(grouping: BuiltinIcons.names) { BuiltinIcons.artwork(for: $0) }.values.map { Set($0) })
            #expect(guideGroups == shippedGroups)
        }
    }

    @Suite("The design system's badge icon colour")
    struct BadgeIconColour {

        @Test("Given the design system's --badge-icon, when read, then light is #ffffff and dark is #14120f, matching the Swift colour")
        func theTokenMatches() {
            let light = StyleGuideSyncTests.cssVars(StyleGuideSyncTests.block(after: ":root {"))["--badge-icon"]
            let dark = StyleGuideSyncTests.cssVars(StyleGuideSyncTests.block(after: "[data-theme=\"dark\"] {"))["--badge-icon"]
            #expect(light == "#ffffff")
            #expect(dark == "#14120f")
            #expect(SemanticColor.badgeIcon.lightHex == "#ffffff")
            #expect(SemanticColor.badgeIcon.darkHex == "#14120f")
        }

        @Test("Given every node type's dark icon background, when its contrast with the dark --badge-icon is computed, then it is at least 3:1")
        func theDarkIconIsReadableOnEveryBackground() throws {
            var backgrounds: [String: String] = [:]
            for (key, style) in try BuiltInNodeTypeStyles.all() {
                let colours: [SemanticColor] = style.walkAll { layout -> SemanticColor? in
                    if case .typeBadge(_, _, let color) = layout { return color }
                    return nil
                }
                for colour in colours { backgrounds[key] = colour.resolve(darkMode: true).hexString }
            }
            #expect(!backgrounds.isEmpty)
            let icon = SemanticColor.badgeIcon.resolve(darkMode: true).hexString
            let tooFaint = backgrounds.filter { contrast(icon, $0.value) < 3 }
            #expect(tooFaint.isEmpty, "below 3:1 on \(tooFaint.keys.sorted())")
        }

        private func luminance(_ hex: String) -> Double {
            let digits = hex.dropFirst()
            let channels = stride(from: 0, to: 6, by: 2).map { offset -> Double in
                let start = digits.index(digits.startIndex, offsetBy: offset)
                let value = Double(Int(digits[start..<digits.index(start, offsetBy: 2)], radix: 16)!) / 255
                return value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]
        }

        private func contrast(_ a: String, _ b: String) -> Double {
            let (hi, lo) = (max(luminance(a), luminance(b)), min(luminance(a), luminance(b)))
            return (hi + 0.05) / (lo + 0.05)
        }
    }
}
