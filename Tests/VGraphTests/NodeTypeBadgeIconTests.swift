import TestSupport
import Testing

@testable import VGraph

@Suite("Built-in notations' node type badges")
struct NodeTypeBadgeIconTests {

    private static func approved() -> [String: String] {
        var table = ApprovedIcons.nodeTypes
        for notation in ["CRT", "FRT", "TRT"] {
            for (type, icon) in ApprovedIcons.reality { table["\(notation).\(type)"] = icon }
        }
        table["Annotation.Annotation"] = "annotation"
        table["Annotation.Warning"] = "warning"
        return table
    }

    @Test(
        "Given the approved list of node types and their icon names, when each built-in notation's node type badge is read, then it names the approved icon"
    )
    func eachNodeTypeNamesItsApprovedIcon() throws {
        let styles = Dictionary(uniqueKeysWithValues: try BuiltInNodeTypeStyles.all().map { ($0.key, $0.style) })
        for (key, icon) in Self.approved() {
            let style = try #require(styles[key], "\(key) has no style")
            #expect(style.extractIcons() == [icon], "\(key) should name \(icon)")
        }
    }

    @Test("Given every built-in notation, when its node type badges are read, then each names an icon that resolves")
    func everyNodeTypeBadgeNamesAnIconThatResolves() throws {
        let badges = try BuiltInNodeTypeStyles.all().filter { BuiltInNodeTypeStyles.wearsNodeTypeBadge($0.style) }
        #expect(!badges.isEmpty)
        for (key, style) in badges {
            let names = style.extractIcons()
            #expect(!names.isEmpty, "\(key) wears a node type badge that names no icon")
            for name in names {
                #expect(BuiltinIcons.artwork(for: name) != nil, "\(key) names \(name), which resolves to nothing")
            }
        }
    }

    @Test(
        "Given all built-in notations, when the icon names used by their node type badges and Arithmetic operators are collected, then each of the 43 approved names is used"
    )
    func everyApprovedNameIsUsed() throws {
        let used = try BuiltInNodeTypeStyles.all().reduce(into: Set<String>()) { $0.formUnion($1.style.extractIcons()) }
        let unused = ApprovedIcons.names.subtracting(ApprovedIcons.unusedByBuiltins).subtracting(used)
        #expect(unused.isEmpty, "no built-in notation uses \(unused.sorted())")
    }

    @Test(
        "Given Concept Map and the annotation extension, when their node types are read, then Concept, Annotation and Warning each wear a node type badge"
    )
    func theNewNodeTypesWearABadge() throws {
        let styles = Dictionary(uniqueKeysWithValues: try BuiltInNodeTypeStyles.all().map { ($0.key, $0.style) })
        let expected = [
            "ConceptMap.Concept": "concept",
            "Annotation.Annotation": "annotation", "Annotation.Warning": "warning",
        ]
        for (key, icon) in expected {
            let style = try #require(styles[key], "\(key) has no style")
            #expect(BuiltInNodeTypeStyles.wearsNodeTypeBadge(style), "\(key) wears no node type badge")
            #expect(style.extractIcons() == [icon], "\(key) should name \(icon)")
        }
    }

    @Test("Given CLD, whose Stock is its only node type, when its node types are read, then Stock wears no node type badge")
    func aSingleTypeNotationWearsNoBadge() throws {
        let styles = Dictionary(uniqueKeysWithValues: try BuiltInNodeTypeStyles.all().map { ($0.key, $0.style) })
        let stock = try #require(styles["CLD.Stock"])
        #expect(!BuiltInNodeTypeStyles.wearsNodeTypeBadge(stock))
    }
}
