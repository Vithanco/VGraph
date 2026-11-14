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
        table["Arithmetic.EqualsIncorrect"] = "not-equal"
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
            if !key.hasPrefix("Arithmetic.") {
                #expect(BuiltInNodeTypeStyles.wearsNodeTypeBadge(style), "\(key) wears no node type badge")
            }
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
}
